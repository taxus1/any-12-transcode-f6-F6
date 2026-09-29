package com.somepro.interfaces.rest.job.converter;

import com.somepro.domain.job.model.TranscodeJob;
import com.somepro.domain.shared.model.PageResult;
import com.somepro.interfaces.rest.common.vo.PageVO;
import com.somepro.interfaces.rest.job.vo.TranscodeJobVO;

import java.util.List;
import java.util.stream.Collectors;

/**
 * TranscodeJob（领域）→ TranscodeJobVO（对外）转换器（用户接口层）。
 *
 * 接口层是唯一做领域对象 → VO 转换的地方：Controller 不许直接把领域对象塞进 Result 返回，
 * 否则 delFlag / createBy / updateBy 等内部字段会被无意识序列化出去。
 */
public final class TranscodeJobVoConverter {

    private TranscodeJobVoConverter() {
    }

    public static TranscodeJobVO toVo(TranscodeJob domain) {
        return new TranscodeJobVO(
                domain.getId(),
                domain.getJobNo(),
                domain.getAssetId(),
                domain.getProfileId(),
                domain.getOwnerDept(),
                domain.getPriority(),
                domain.getStatus() == null ? null : domain.getStatus().name(),
                domain.getAttemptCount(),
                domain.getMaxAttempts(),
                domain.getProgress(),
                domain.getOutputPath(),
                domain.getErrorMsg(),
                domain.getSubmittedAt(),
                domain.getStartedAt(),
                domain.getFinishedAt(),
                domain.getReviewResult(),
                domain.getReviewComment(),
                domain.getReviewBy(),
                domain.getReviewTime(),
                domain.getCreateTime());
    }

    public static PageVO<TranscodeJobVO> toPageVo(PageResult<TranscodeJob> page) {
        List<TranscodeJobVO> content = page.content().stream()
                .map(TranscodeJobVoConverter::toVo)
                .collect(Collectors.toList());
        return new PageVO<>(content, page.total(), page.pageNum(), page.pageSize(), page.totalPages());
    }
}
