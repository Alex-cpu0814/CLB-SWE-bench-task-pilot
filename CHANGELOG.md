# CLB 变更日志

## 未发布

- 72 题统一使用 `image` 指向 Docker Hub 上的 `yutu0814/sweb.eval.x86_64.*:latest` Base 镜像。
- `clb` 命令适配 Base 镜像字段并复用官方 SWE-bench 的推理、评测、校验和导出流程。
- 将数据导出步骤合并到仓库首页，新旧实例 ID 对照表移入 `docs/`，历史复测材料保存在提交 `ccb644f`。
- 将生成器命令入口和评测模板集中到 `dockerfile_gen/__init__.py`。安装后通过 `dockerfile-gen` 或 `clb-dockerfile-gen` 运行。
- 按项目共享构建步骤，按题配置测试命令。Dockerfile 内嵌评测辅助文件，历史复测工具移入 `tools/archive/`。
- 将 Base 镜像清单放入 `dockerfile_gen/data/`。
- 生成器支持 `dockerfile-gen --instance_ids`，SWE-bench 依赖由 `pyproject.toml` 固定。
- 将 72 题的数据集标识设为 `Alex-cpu0814/CLB-SWE-bench`。
- 新增官方格式的 `eval/` 描述文件和 Hugging Face 数据集卡片。官方导出命令会随 Parquet 导出 `eval.yaml`。
- 新增 `clb-dockerfile-gen` 可安装命令。
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
- 实例 ID 改用仓库名称和原案例号，旧 ID 保存在[对照表](docs/instance-id-map.tsv)。
- 固定 SWE-bench 5.0.2 的上游提交，沿用各题的题面、参考补丁、测试补丁和测试列表。
