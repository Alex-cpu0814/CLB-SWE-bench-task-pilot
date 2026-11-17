# CLB SWE-bench 任务仓库

CLB SWE-bench 是一个跨语言软件修复数据集，包含 72 个 Python–C 和 Java–C 任务。
模型从题面和固定版本的代码出发生成补丁，再由官方 SWE-bench 评测器运行测试。
[Hugging Face 数据集](https://huggingface.co/datasets/Alex-cpu0814/CLB-SWE-bench) · [任务索引](tasks/README.md)

| 任务分组 | 数量 |
| --- | ---: |
| Python–C | 50 |
| Java–C（CLB 编写的测试） | 11 |
| Java–C（上游测试） | 11 |

## 安装

以下命令在 Linux Bash 中运行，Windows 用户可在 WSL 2 中执行。
需要 Git、Python 3.10+（建议 3.11 或更新版本）和支持 Linux amd64 镜像的 Docker。评测时还需要 Docker Buildx。

~~~bash
git clone https://github.com/Alex-cpu0814/CLB-SWE-bench-task-pilot.git
cd CLB-SWE-bench-task-pilot
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e .
~~~

安装时会一并安装仓库固定的 SWE-bench 5.0.2 版本。后续命令都在仓库根目录的同一个 Python 环境里运行。

## 生成模型补丁

安装 `mini-swe-agent`，配置模型供应商要求的 API 密钥和环境变量，并将 Bash 变量 `MODEL` 设为模型 ID。
下面以 Fast Histogram 159 为例。mini-SWE-agent 会读取数据集中的 `problem_statement`，并在 `image_name` 指定的 Base 镜像中生成补丁。

~~~bash
python -m pip install mini-swe-agent
swebench infer Alex-cpu0814/CLB-SWE-bench \
    -m "$MODEL" \
    --run-id clb-159 \
    -w 1 \
    -- --filter '^astrofrog__fast-histogram-clb-159$'
~~~

预测写入 `logs/inference/clb-159/preds.json`，轨迹也保存在该次运行的目录下。
要运行完整的 `test` split，省略筛选行和它上一行末尾的反斜杠。
`-w` 设置生成补丁时的并行题数。

## 评测

`--task-repo .` 指向当前的任务仓库。SWE-bench 使用其中的 `Dockerfile` 构建评测镜像，将模型补丁应用到对应的起始代码，再运行评测脚本。

### 评测模型补丁

~~~bash
swebench eval Alex-cpu0814/CLB-SWE-bench \
    -p logs/inference/clb-159/preds.json \
    -i astrofrog__fast-histogram-clb-159 \
    --run-id clb-159 \
    -j 1 \
    --task-repo .
~~~

结果写入 `logs/evaluation/clb-159/results.json`。全部 `FAIL_TO_PASS` 和 `PASS_TO_PASS` 测试通过时，该题判为已修复。
评测一批预测时，将 `-p` 指向批量预测文件并省略 `-i`。评测新一轮预测时使用新的 `--run-id`，避免复用上一次的报告。

也可以提交自己的 `predictions.jsonl`。每行包含 `instance_id`、`model_name_or_path` 和统一 diff 格式的 `model_patch`。

### 验证参考补丁

`--gold` 使用数据集中的参考补丁，可用于检查构建、测试和评分流程。

~~~bash
swebench eval Alex-cpu0814/CLB-SWE-bench --gold \
    -i astrofrog__fast-histogram-clb-159 \
    --run-id clb-159-gold \
    -j 1 \
    --task-repo .
~~~

## 仓库结构

- `tasks/<instance_id>/` 存放任务元数据、题面、参考补丁、测试补丁和已生成的评测文件。[任务索引](tasks/README.md) · [新旧实例 ID 对照表](docs/instance-id-map.tsv)
- `dockerfile_gen/` 按 Python–C 和 Java–C 的配置生成 `Dockerfile` 与 `eval.sh`。其中的 `fixtures/` 存放构建、测试运行和日志处理的辅助文件。[生成器](dockerfile_gen/) · [Base 镜像清单](dockerfile_gen/data/base-images.json)
- `sweb.yaml` 注册数据集和 split，`eval/` 存放评测配置。[数据集注册](sweb.yaml) · [评测配置](eval/CLB-SWE-bench.yaml)

## 维护与导出

修改构建或测试配置后，可重新生成指定任务的文件。省略 `--instance_ids` 会重新生成所有任务。`--check` 检查仓库中的生成文件是否与当前配置一致。

~~~bash
dockerfile-gen --instance_ids astrofrog__fast-histogram-clb-159
dockerfile-gen --check
~~~

用官方 CLI 校验并导出数据集。

~~~bash
swebench dataset check .
swebench dataset build . -o scratch/dataset
cp docs/dataset-card.md scratch/dataset/CLB-SWE-bench/README.md
~~~

导出目录 `scratch/dataset/CLB-SWE-bench/` 包含 `test.parquet`、`eval.yaml` 和数据集卡片。
[Base 和 Gold 验证记录](docs/validation.md) · [题面审核](docs/pilot-task-review.md) · [变更日志](CHANGELOG.md)
