-- any-12-transcode · 音视频文件转码服务 · 建表 SQL
-- 字符集 utf8mb4，时区 Asia/Shanghai。create 阶段建好，模型只写业务代码，不碰建表。
-- 列名即契约：del_flag 由 @TableLogic 自动拼接（查询带 del_flag=0，删除置 1），
-- create_by/update_by/create_time/update_time 由 AutoFillMetaObjectHandler 自动填充，业务代码不要手写。
-- 主键 id 由应用侧雪花分配（IdType.INPUT），不依赖自增。

-- 1) 素材文件档案（上传进来的原始音视频文件）
CREATE TABLE IF NOT EXISTS t_media_asset (
    id           BIGINT       NOT NULL PRIMARY KEY COMMENT '雪花 ID，应用层分配',
    asset_code   VARCHAR(32)  NOT NULL COMMENT '素材编号，全局唯一（如 MA-2026-0001）',
    file_name    VARCHAR(255) NOT NULL COMMENT '原始文件名',
    media_type   VARCHAR(16)  NOT NULL COMMENT 'AUDIO 音频 / VIDEO 视频 / IMAGE 图片',
    file_ext     VARCHAR(16)  DEFAULT NULL COMMENT '扩展名（mp3/mp4/...）',
    size_bytes   BIGINT       DEFAULT NULL COMMENT '文件字节数',
    duration_ms  BIGINT       DEFAULT NULL COMMENT '时长（毫秒）',
    checksum     VARCHAR(64)  DEFAULT NULL COMMENT '内容校验值',
    owner_dept   VARCHAR(64)  NOT NULL COMMENT '归属部门（配额与台账按它归集）',
    status       VARCHAR(16)  NOT NULL DEFAULT 'READY' COMMENT 'READY 可转码 / TRANSCODING 转码中 / DONE 已完成 / DISABLED 已停用',
    del_flag     TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除：0 正常 / 1 已删除',
    create_by    VARCHAR(64)  DEFAULT NULL,
    create_time  DATETIME     DEFAULT NULL,
    update_by    VARCHAR(64)  DEFAULT NULL,
    update_time  DATETIME     DEFAULT NULL,
    UNIQUE KEY uk_asset_code (asset_code),
    KEY idx_owner (owner_dept),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='素材文件档案';

-- 2) 转码档位（目标规格：格式、分辨率、码率）
CREATE TABLE IF NOT EXISTS t_transcode_profile (
    id                  BIGINT      NOT NULL PRIMARY KEY COMMENT '雪花 ID，应用层分配',
    profile_code        VARCHAR(32) NOT NULL COMMENT '档位编号，全局唯一（如 PF-001）',
    profile_name        VARCHAR(64) NOT NULL COMMENT '档位名称',
    media_type          VARCHAR(16) NOT NULL COMMENT '适用媒体类型 AUDIO / VIDEO',
    target_format       VARCHAR(16) NOT NULL COMMENT '目标格式（mp3/mp4/wav）',
    width               INT         DEFAULT NULL COMMENT '目标宽度（音频档位为空）',
    height              INT         DEFAULT NULL COMMENT '目标高度（音频档位为空）',
    video_bitrate_kbps  INT         DEFAULT NULL COMMENT '目标视频码率 kbps（音频档位为空）',
    audio_bitrate_kbps  INT         DEFAULT NULL COMMENT '目标音频码率 kbps',
    status              VARCHAR(16) NOT NULL DEFAULT 'ENABLED' COMMENT 'ENABLED 启用 / DISABLED 停用',
    del_flag            TINYINT     NOT NULL DEFAULT 0 COMMENT '逻辑删除：0 正常 / 1 已删除',
    create_by           VARCHAR(64) DEFAULT NULL,
    create_time         DATETIME    DEFAULT NULL,
    update_by           VARCHAR(64) DEFAULT NULL,
    update_time         DATETIME    DEFAULT NULL,
    UNIQUE KEY uk_profile_code (profile_code),
    KEY idx_media_type (media_type),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='转码档位配置';

-- 3) 转码任务（一个素材按一个档位转一次）
CREATE TABLE IF NOT EXISTS t_transcode_job (
    id            BIGINT      NOT NULL PRIMARY KEY COMMENT '雪花 ID，应用层分配',
    job_no        VARCHAR(32) NOT NULL COMMENT '任务编号，全局唯一（如 TJ-2026-0001）',
    asset_id      BIGINT      NOT NULL COMMENT '素材 id（t_media_asset.id）',
    profile_id    BIGINT      NOT NULL COMMENT '档位 id（t_transcode_profile.id）',
    owner_dept    VARCHAR(64) NOT NULL COMMENT '归属部门（冗余自素材，配额与台账按它归集）',
    priority      INT         NOT NULL DEFAULT 5 COMMENT '优先级，越小越先做',
    status        VARCHAR(16) NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING 待处理 / RUNNING 处理中 / SUCCESS 成功（待审）/ DONE 已完成（审核通过）/ FAILED 失败（跑失败或审核驳回）/ CANCELLED 已取消',
    attempt_count INT         NOT NULL DEFAULT 0 COMMENT '已尝试次数',
    max_attempts  INT         NOT NULL DEFAULT 3 COMMENT '最多尝试次数',
    progress      INT         NOT NULL DEFAULT 0 COMMENT '进度 0-100',
    output_path   VARCHAR(255) DEFAULT NULL COMMENT '产出文件路径',
    error_msg     VARCHAR(255) DEFAULT NULL COMMENT '最近一次失败原因',
    submitted_at  DATETIME    DEFAULT NULL COMMENT '提交时刻',
    started_at    DATETIME    DEFAULT NULL COMMENT '开始处理时刻',
    finished_at   DATETIME    DEFAULT NULL COMMENT '结束时刻',
    review_result VARCHAR(16) DEFAULT NULL COMMENT 'PASS 审核通过 / REJECT 审核驳回',
    review_comment VARCHAR(255) DEFAULT NULL COMMENT '审核意见',
    review_by     VARCHAR(64) DEFAULT NULL COMMENT '审核人（登录账号）',
    review_time   DATETIME    DEFAULT NULL COMMENT '审核时刻',
    del_flag      TINYINT     NOT NULL DEFAULT 0 COMMENT '逻辑删除：0 正常 / 1 已删除',
    create_by     VARCHAR(64) DEFAULT NULL,
    create_time   DATETIME    DEFAULT NULL,
    update_by     VARCHAR(64) DEFAULT NULL,
    update_time   DATETIME    DEFAULT NULL,
    UNIQUE KEY uk_job_no (job_no),
    KEY idx_asset (asset_id),
    KEY idx_profile (profile_id),
    KEY idx_status (status),
    KEY idx_owner_time (owner_dept, submitted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='转码任务';

-- 4) 任务执行尝试（每次真正跑一遍记一条）
CREATE TABLE IF NOT EXISTS t_job_attempt (
    id          BIGINT      NOT NULL PRIMARY KEY COMMENT '雪花 ID，应用层分配',
    job_id      BIGINT      NOT NULL COMMENT '转码任务 id（t_transcode_job.id）',
    attempt_no  INT         NOT NULL COMMENT '第几次尝试，从 1 起',
    worker_code VARCHAR(32) DEFAULT NULL COMMENT '执行的转码节点编号',
    status      VARCHAR(16) NOT NULL DEFAULT 'RUNNING' COMMENT 'RUNNING 执行中 / SUCCESS 成功 / FAILED 失败',
    error_code  VARCHAR(32) DEFAULT NULL COMMENT '失败错误码',
    error_msg   VARCHAR(255) DEFAULT NULL COMMENT '失败说明',
    started_at  DATETIME    DEFAULT NULL COMMENT '开始时刻',
    finished_at DATETIME    DEFAULT NULL COMMENT '结束时刻',
    del_flag    TINYINT     NOT NULL DEFAULT 0 COMMENT '逻辑删除：0 正常 / 1 已删除',
    create_by   VARCHAR(64) DEFAULT NULL,
    create_time DATETIME    DEFAULT NULL,
    update_by   VARCHAR(64) DEFAULT NULL,
    update_time DATETIME    DEFAULT NULL,
    UNIQUE KEY uk_job_attempt (job_id, attempt_no),
    KEY idx_job (job_id),
    KEY idx_worker (worker_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='任务执行尝试';

-- 5) 转码配额（按部门 + 月份限流）
CREATE TABLE IF NOT EXISTS t_transcode_quota (
    id          BIGINT      NOT NULL PRIMARY KEY COMMENT '雪花 ID，应用层分配',
    owner_dept  VARCHAR(64) NOT NULL COMMENT '归属部门',
    period      VARCHAR(7)  NOT NULL COMMENT '配额周期，yyyy-MM',
    used_count  INT         NOT NULL DEFAULT 0 COMMENT '已用条数',
    limit_count INT         NOT NULL DEFAULT 100 COMMENT '配额上限',
    del_flag    TINYINT     NOT NULL DEFAULT 0 COMMENT '逻辑删除：0 正常 / 1 已删除',
    create_by   VARCHAR(64) DEFAULT NULL,
    create_time DATETIME    DEFAULT NULL,
    update_by   VARCHAR(64) DEFAULT NULL,
    update_time DATETIME    DEFAULT NULL,
    UNIQUE KEY uk_dept_period (owner_dept, period),
    KEY idx_period (period)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='转码配额';

-- 6) 回调通知（任务到终态后通知业务方）
CREATE TABLE IF NOT EXISTS t_transcode_callback (
    id           BIGINT       NOT NULL PRIMARY KEY COMMENT '雪花 ID，应用层分配',
    job_id       BIGINT       NOT NULL COMMENT '转码任务 id（t_transcode_job.id）',
    target_url   VARCHAR(255) NOT NULL COMMENT '通知地址',
    status       VARCHAR(16)  NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING 待通知 / SUCCESS 成功 / FAILED 失败',
    retry_count  INT          NOT NULL DEFAULT 0 COMMENT '已重试次数',
    max_retries  INT          NOT NULL DEFAULT 3 COMMENT '最多重试次数',
    last_error   VARCHAR(255) DEFAULT NULL COMMENT '最近一次失败原因',
    next_retry_at DATETIME    DEFAULT NULL COMMENT '下次重试时刻',
    del_flag     TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除：0 正常 / 1 已删除',
    create_by    VARCHAR(64)  DEFAULT NULL,
    create_time  DATETIME     DEFAULT NULL,
    update_by    VARCHAR(64)  DEFAULT NULL,
    update_time  DATETIME     DEFAULT NULL,
    KEY idx_job (job_id),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='回调通知';

-- 7) 转码节点（执行转码的工作机）
CREATE TABLE IF NOT EXISTS t_transcode_worker (
    id              BIGINT      NOT NULL PRIMARY KEY COMMENT '雪花 ID，应用层分配',
    worker_code     VARCHAR(32) NOT NULL COMMENT '节点编号，全局唯一（如 WK-001）',
    worker_name     VARCHAR(64) NOT NULL COMMENT '节点名称',
    status          VARCHAR(16) NOT NULL DEFAULT 'ONLINE' COMMENT 'ONLINE 在线 / OFFLINE 离线 / BUSY 满载',
    max_concurrency INT         NOT NULL DEFAULT 2 COMMENT '并发上限',
    running_count   INT         NOT NULL DEFAULT 0 COMMENT '当前在跑数',
    last_heartbeat  DATETIME    DEFAULT NULL COMMENT '最近心跳时刻',
    del_flag        TINYINT     NOT NULL DEFAULT 0 COMMENT '逻辑删除：0 正常 / 1 已删除',
    create_by       VARCHAR(64) DEFAULT NULL,
    create_time     DATETIME    DEFAULT NULL,
    update_by       VARCHAR(64) DEFAULT NULL,
    update_time     DATETIME    DEFAULT NULL,
    UNIQUE KEY uk_worker_code (worker_code),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='转码节点';
