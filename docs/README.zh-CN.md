# SWE-bench CLB 任务仓库

[English](../README.md)

SWE-bench CLB 是一个跨语言软件修复数据集，包含 72 个 Python–C 和 Java–C 任务。
模型从题面和固定版本的代码出发生成补丁，再由官方 SWE-bench 评测器运行测试。
[Hugging Face 数据集](https://huggingface.co/datasets/Alex-cpu0814/SWE-bench_CLB) · [任务索引](../tasks/README.md)

| 任务分组 | 数量 |
| --- | ---: |
| Python–C （上游测试）| 50 |
| Java–C（作者编写的测试） | 11 |
| Java–C（上游测试） | 11 |

## 安装

以下命令在 Linux Bash 中运行，Windows 用户可在 WSL 2 中执行。
需要 Git、Python 3.10+（建议 3.11 或更新版本）和支持 Linux amd64 镜像的 Docker。

~~~bash
git clone https://github.com/Alex-cpu0814/swe-bench-clb-tasks.git
cd swe-bench-clb-tasks
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e .
~~~

这一步会安装仓库固定的 SWE-bench 5.0.2 及其依赖，并注册 `dockerfile-gen` 命令。
`-e` 让生成器直接使用当前工作区的代码。后续命令都在仓库根目录的同一个 Python 环境里运行。

## 准备本地镜像

运行推理前，请在**同一台 Docker 主机**上执行准备命令。`image` 记录实际发布在 Docker Hub 的地址。
脚本从 `yutu0814/` 拉取本机缺少的镜像，并添加 mini-SWE-agent 根据任务 ID 推导出的 `swebench/` 本地标签。
两个标签引用同一个镜像。

~~~bash
python prepare_dataset.py -o scratch/local-swebench
~~~

要校验本地任务，运行 `swebench dataset check scratch/local-swebench/task-repo`。
后面的推理和评测命令也可以将数据集名称替换成 `scratch/local-swebench/dataset/SWE-bench_CLB`，直接使用导出的本地 Parquet。

## 验证参考补丁

先用 `--gold` 评测 Fast Histogram 159 的参考补丁，确认镜像、测试和评分流程可用。

~~~bash
swebench eval Alex-cpu0814/SWE-bench_CLB --gold \
    -i astrofrog__fast-histogram-clb-159 \
    --run-id clb-159-gold \
    -j 1
~~~

## 生成模型补丁

安装 `mini-swe-agent`，配置模型供应商要求的 API 密钥和环境变量，并将 Bash 变量 `MODEL` 设为模型 ID。
下面以 Fast Histogram 159 为例。mini-SWE-agent 从准备好的本地镜像启动容器并生成补丁。

~~~bash
python -m pip install mini-swe-agent
swebench infer Alex-cpu0814/SWE-bench_CLB \
    -m "$MODEL" \
    --run-id clb-159 \
    -w 1 \
    -- --filter '^astrofrog__fast-histogram-clb-159$'
~~~

预测写入 `logs/inference/clb-159/preds.json`，轨迹也保存在该次运行的目录下。
要运行完整的 `test` split，省略筛选行和它上一行末尾的反斜杠。
`-w` 设置生成补丁时的并行题数。

## 评测模型补丁

`swebench eval` 从数据集读取 `image` 并启动同一镜像的新容器。评测器应用候选补丁后，`eval.sh` 再应用测试补丁、准备辅助文件并运行测试。

~~~bash
swebench eval Alex-cpu0814/SWE-bench_CLB \
    -p logs/inference/clb-159/preds.json \
    -i astrofrog__fast-histogram-clb-159 \
    --run-id clb-159 \
    -j 1
~~~

结果写入 `logs/evaluation/clb-159/results.json`。全部 `FAIL_TO_PASS` 和 `PASS_TO_PASS` 测试通过时，该题判为已修复。
评测一批预测时，将 `-p` 指向批量预测文件并省略 `-i`。评测新一轮预测时使用新的 `--run-id`，避免复用上一次的报告。

也可以提交自己的 `predictions.jsonl`。每行包含 `instance_id`、`model_name_or_path` 和统一 diff 格式的 `model_patch`。

## 仓库结构

- `tasks/<instance_id>/` 存放任务元数据、题面、参考补丁、测试补丁和已生成的评测文件。[任务索引](../tasks/README.md) · [新旧实例 ID 对照表](instance-id-map.tsv)
- `dockerfile_gen/` 按 Python–C 和 Java–C 的配置生成 `Dockerfile` 与 `eval.sh`。`fixtures/` 存放嵌入评测脚本的构建、测试运行和日志处理文件。[生成器](../dockerfile_gen/)
- `sweb.yaml` 注册数据集和 split，`eval/` 存放评测配置。[数据集注册](../sweb.yaml) · [评测配置](../eval/SWE-bench_CLB.yaml)

## 维护与导出

修改构建或测试配置后，可重新生成指定任务的文件。省略 `--instance_ids` 会重新生成所有任务。`--check` 检查仓库中的生成文件是否与当前配置一致。

~~~bash
dockerfile-gen --instance_ids astrofrog__fast-histogram-clb-159
dockerfile-gen --check
~~~

`--for-publish` 在导出发布数据时执行 SWE-bench 的任务校验，并将实际的 `yutu0814/` 镜像地址写入 `image`。

~~~bash
python prepare_dataset.py --for-publish -o scratch/dataset
~~~

导出目录 `scratch/dataset/SWE-bench_CLB/` 包含 `test.parquet`、`eval.yaml` 和数据集卡片。
发布前可以将示例命令中的数据集名换成本地导出的数据集目录，验证当前改动。
[验证结果](validation.md) · [变更日志](../CHANGELOG.md)
