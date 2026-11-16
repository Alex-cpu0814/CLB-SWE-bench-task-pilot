# CLB 变更日志

## 未发布

- 将 72 题的数据集标识设为 `Alex-cpu0814/CLB-SWE-bench`。
- 新增官方格式的 `eval/` 描述文件和 Hugging Face 数据集卡片。官方导出命令会随 Parquet 导出 `eval.yaml`。
- 新增 `clb-dockerfile-gen` 可安装命令，`python -m dockerfile_gen` 继续可用。
- 将导入工具、复测工具及历史候选材料放到 `tools/`，把验证与题面审核记录移到 `docs/`。

## 任务生成器 `4853785`

- 从当前任务仓库重新生成 72 个 Dockerfile 和 72 个 `eval.sh`，支持按题选择和 `--check`。
- 全量生成文件与原版逐字节一致，三题的六次 Base／Gold 对照与归档一致。

## Base 镜像与复现 `4134aac`、`558b990`

- 将 72 题切换到 `yutu0814/clb.base.x86_64.*:latest`，按题锁定镜像摘要。
- 72 个 Base 控制均未解决，72 个 Gold 控制均通过。三道代表题完成空构建缓存复现。
- LWJGL `075` 的依赖路径、junixsocket `160` 的并行超时和 Pycairo `139` 的 Base 中止记录见[验证记录](docs/validation.md#新-base-镜像验证)。

## 72 题任务迁移 `31fe954`

- 从冻结版迁移 50 个 Python–C、11 个 Java–C 作者测试和 11 个 Java–C 上游测试任务。
- 实例 ID 改用仓库名称和原案例号，旧 ID 保存在[对照表](instance-id-map.tsv)。
- 固定 SWE-bench 5.0.2 的上游提交，沿用各题的题面、参考补丁、测试补丁和测试列表。
