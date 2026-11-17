# CLB 验证结果

在 WSL 2 和 Linux amd64 Docker 环境中，使用仓库固定的 SWE-bench 5.0.2 对全部 72 条任务运行评测。

| 对照 | 已完成 | 判定为已修复 |
| --- | ---: | ---: |
| 参考补丁（Gold） | 72 | 72 |
| 无关补丁 | 72 | 0 |

无关补丁均成功应用并执行测试。junixsocket 160 的参考补丁在首轮并行评测中触发 Maven 超时，串行复测通过。

[历史验证、迁移和复现记录](https://github.com/Alex-cpu0814/swe-bench-clb-tasks/blob/3b916e2fbc756ce8868b93b2a46d93c32f0ddeef/docs/validation.md)
