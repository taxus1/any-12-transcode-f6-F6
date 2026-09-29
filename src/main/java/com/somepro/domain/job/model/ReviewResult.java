package com.somepro.domain.job.model;

import com.somepro.common.exception.BizException;

/**
 * 审核结论（领域枚举）：PASS 通过 / REJECT 驳回。
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
