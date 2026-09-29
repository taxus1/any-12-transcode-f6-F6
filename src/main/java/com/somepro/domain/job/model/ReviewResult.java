package com.somepro.domain.job.model;

import com.somepro.common.exception.BizException;

/**
 * 审核结论（领域枚举）：PASS 通过 / REJECT 驳回。
 *
 * 只有跑成功（SUCCESS）的转码任务才等人审（见 TranscodeJob.review）：
 * - PASS：任务落 DONE（到此为止），挂着的素材算完成（DONE），不再进待审清单；
 * - REJECT：任务落 FAILED（审核驳回的失败，不允许重试覆盖，只能重新提），素材退回可转码（READY）。
 * 驳回必须写明审核意见（哪不行），通过可以不写意见。
 */
public enum ReviewResult {

    PASS, REJECT;

    /** 按名字解析（大小写不敏感）；非法值抛业务异常。 */
    public static ReviewResult of(String value) {
        if (value == null || value.isBlank()) {
            throw new BizException("审核结论不能为空（PASS/REJECT）");
        }
        try {
            return ReviewResult.valueOf(value.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new BizException("审核结论只支持 PASS/REJECT：" + value);
        }
    }
}
