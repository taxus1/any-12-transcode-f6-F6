package com.somepro.domain.job.model;

import com.somepro.common.exception.BizException;

/**
 * 转码任务状态（领域枚举）：
 * PENDING 待处理 / RUNNING 处理中 / SUCCESS 成功（跑成功，等人审）/ DONE 已完成（审核通过，到此为止）
 * / FAILED 失败 / CANCELLED 已取消。
 *
 * 新提交的任务一律 PENDING（见 TranscodeJob.submit），后续状态由节点领取、执行流程推进；
 * 只有 PENDING 还允许撤销。FAILED 在尝试次数未到上限且「没被审核驳回过」时可重排回 PENDING
 * （见 TranscodeJob.retry）；审核驳回落成的 FAILED 是终局，结论不许被新结论或重试覆盖，只能重新提。
 * 审核通过落成的 DONE 与到了上限的 FAILED / CANCELLED 一样都是不再流转的终态。
 */
public enum JobStatus {

    PENDING, RUNNING, SUCCESS, DONE, FAILED, CANCELLED;

    /** 按名字解析（大小写不敏感）；非法值抛业务异常。 */
    public static JobStatus of(String value) {
        if (value == null || value.isBlank()) {
            throw new BizException("任务状态不能为空（PENDING/RUNNING/SUCCESS/DONE/FAILED/CANCELLED）");
        }
        try {
            return JobStatus.valueOf(value.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new BizException(
                    "任务状态只支持 PENDING/RUNNING/SUCCESS/DONE/FAILED/CANCELLED：" + value);
        }
    }
}
