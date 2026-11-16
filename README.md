# CLB SWE-bench 任务仓库

CLB 收录 72 个跨语言修复任务，包括 50 个 Python–C、11 个 Java–C 作者测试和
11 个 Java–C 上游测试任务。任务使用 SWE-bench 5.0.2 评测。
[Hugging Face 数据集](https://huggingface.co/datasets/Alex-cpu0814/CLB-SWE-bench)

## 仓库结构

`tasks/<instance_id>/` 存放每道题的题面、补丁、测试列表、评测脚本和 Docker 构建输入。
`dockerfile_gen/` 生成这些目录中的 `Dockerfile` 和 `eval.sh`。
`sweb.yaml` 注册数据集及其分割，`eval/` 存放发布用的评测配置。
[任务索引](tasks/README.md) · [维护与复测](tools/README.md)

## 安装和生成

在仓库根目录运行。需要 Linux、Python 3.10+、Git 和支持 Linux amd64 镜像的 Docker。
Windows 上使用 WSL 2。

~~~bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e .
dockerfile-gen --check
~~~

`dockerfile-gen` 会重新生成所有任务的 `Dockerfile` 和 `eval.sh`。可用
`dockerfile-gen --instance_ids scipy__scipy-clb-002` 只生成指定任务。
生成器从 Python–C、Java–C 配置和共享辅助文件生成完整的评测 Dockerfile。构建时需要 Docker Buildx，
并使用按 SHA-256 固定的 Base 镜像。[生成器](dockerfile_gen/) · [Base 镜像清单](dockerfile_gen/data/base-images.json)

## 评测

用官方评测器从任务仓库构建三道代表题的镜像并验证参考补丁。

~~~bash
swebench eval Alex-cpu0814/CLB-SWE-bench --task-repo . --gold \
  -i scipy__scipy-clb-002 -i ninia__jep-clb-093 -i kohlschutter__junixsocket-clb-175 \
  --run-id clb-pilot-gold -j 1
~~~

评测模型补丁时，把 `--gold` 换成 `-p predictions.jsonl`。每行包含
`instance_id`、`model_name_or_path` 和统一 diff 格式的 `model_patch`。
省略三个 `-i` 可评测预测文件中提交的任务。生成模型补丁时提供题面和对应的 Base 环境。

[题面审核](docs/pilot-task-review.md) · [Base 和 Gold 验证记录](docs/validation.md) · [变更日志](CHANGELOG.md)
