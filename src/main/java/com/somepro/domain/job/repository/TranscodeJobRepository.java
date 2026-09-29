package com.somepro.domain.job.repository;

import com.somepro.domain.job.model.JobAttempt;
import com.somepro.domain.job.model.TranscodeJob;
import com.somepro.domain.shared.model.PageResult;
import reactor.core.publisher.Mono;

import java.util.List;

/**
 * 转码任务聚合的仓储端口：由领域层定义，基础设施层实现（端口-适配器）。
 *
 * 分页条件全部可空：一个条件都不填时就是全量分页（表里早先录的数据也要能翻出来）。
 */
public interface TranscodeJobRepository {

    /**
     * 落库一条新任务（提交用例专用）：
     * - 在事务里锁住素材行（FOR UPDATE），锁内复查「同素材同档位无未完成任务」，
     *   挡住并发重复提交；
     * - 分配任务编号（TJ-年份-四位序号，按年递增），uk_job_no 唯一索引兜底，撞号自动重试。
     */
    Mono<TranscodeJob> submitNew(TranscodeJob job);

    Mono<TranscodeJob> findById(Long id);

    /** 同素材同档位是否已有未完成任务（PENDING/RUNNING）。 */
    Mono<Boolean> existsActiveByAssetAndProfile(Long assetId, Long profileId);

    Mono<PageResult<TranscodeJob>> page(int pageNum, int pageSize, String jobNo, String status,
                                        String ownerDept, Long assetId, Long profileId);

    /**
     * 待审清单：按归属部门分页，只包含转码成功且还没有审核结论的任务。
     * 已删除任务由 @TableLogic 自动排除；审核通过或驳回后都不会再出现在清单里。
     */
    Mono<PageResult<TranscodeJob>> pagePendingReview(int pageNum, int pageSize, String ownerDept);

    /**
     * 审核落库（乐观条件更新，一个事务里两件事）：
     * ① 仅当库里仍是 SUCCESS 且 review_result IS NULL 才写入结论、审核人与审核时刻；
     *   驳回同时把任务改成 FAILED，通过则保持 SUCCESS。两个人同时点只认先到的一次，
     *   后来的 rows=0，原有结论、审核人和审核时刻均不被覆盖；
     * ② 素材联动：通过改成 DONE，驳回退回 READY。
     */
    Mono<TranscodeJob> reviewIfSuccessPending(TranscodeJob job);

    /**
     * 撤销落库（乐观条件更新）：仅当库里仍是 PENDING 才更新为 CANCELLED，
     * 防止「查出来是待处理 → 节点同时领走 → 又被撤销」的并发窗口。
     */
    Mono<TranscodeJob> cancelIfPending(TranscodeJob job);

    /**
     * 重排（重试）落库（乐观条件更新，一个事务里两件事）：
     * ① 仅当库里仍是 FAILED 才把任务改回 PENDING，并清掉失败说明、进度归零、起止时刻清空
     *    （attempt_count 不动，下次领取时接着往下排，不在这里新增执行记录）——
     *    同一条任务被连点几下、或几个人同时点，InnoDB 行锁把请求串行，只有第一个 UPDATE
     *    rows=1，其余 rows=0，保证只排一次、不重复入队；PENDING/RUNNING/SUCCESS/CANCELLED
     *    以及审核驳回的 FAILED 同样在这里被挡回；
     * ② 对应素材跟着退回可转码（READY），等任务再次被领走时再进转码中。
     */
    Mono<TranscodeJob> requeueIfFailed(TranscodeJob job);

    /**
     * 领取落库（乐观条件更新，一个事务里三件事）：
     * ① 仅当库里仍是 PENDING 才把任务改成 RUNNING —— 几个节点同时抢也只放一台，
     *    其余 rows=0 给明确提示；已被领走的、已出结果的同样在这里被挡回；
     * ② 对应素材跟着进转码中（TRANSCODING）；
     * ③ 插入一条执行记录（第几次跑、哪台节点、几点开始）。
     */
    Mono<TranscodeJob> claimIfPending(TranscodeJob job, JobAttempt attempt);

    /**
     * 进度落库（乐观条件更新）：仅当库里仍是 RUNNING 且库里的进度不超过本次上报值才更新，
     * 防止「读出来 50 → 另一上报已推进到 80 → 本次 60 把进度写回退」的并发窗口。
     */
    Mono<TranscodeJob> reportProgressIfRunning(TranscodeJob job);

    /**
     * 结果落库（乐观条件更新，一个事务里三件事）：
     * ① 仅当库里仍是 RUNNING 才把任务改成终态（SUCCESS/FAILED）—— 已出结果的任务
     *    后面再怎么报都不会被重新改一遍；
     * ② 素材联动：成功留在转码中等人审（不动），失败退回可转码（READY）；
     * ③ 当前这条执行记录跟着收尾（只更新，不新增）。
     */
    Mono<TranscodeJob> finishIfRunning(TranscodeJob job);

    /** 某任务的执行记录（第几次跑、哪台节点、起止时刻），按 attemptNo 升序。 */
    Mono<List<JobAttempt>> listAttempts(Long jobId);
}
