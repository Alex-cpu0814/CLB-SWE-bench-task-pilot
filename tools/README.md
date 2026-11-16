# CLB 任务维护

以下命令从任务仓库根目录运行。依赖安装见[仓库首页](../README.md#安装和生成)。
原有的 `clb-dockerfile-gen` 和 `python -m dockerfile_gen` 也可以调用生成器。

## 更新构建或测试命令

在 `python_c.py` 或 `java_c.py` 修改项目共用的构建步骤、个别题的构建配置或测试命令。
可共用的辅助文件放在 `dockerfile_gen/fixtures/`。运行 `dockerfile-gen --instance_ids <instance_id>`
重新生成对应题目的 `Dockerfile` 和 `eval.sh`，运行 `dockerfile-gen --check` 检查全部任务。
[Python–C 配置](../dockerfile_gen/python_c.py) · [Java–C 配置](../dockerfile_gen/java_c.py)

## 导出数据

~~~bash
swebench dataset check .
swebench dataset build . -o scratch/dataset
cp docs/dataset-card.md scratch/dataset/CLB-SWE-bench/README.md
~~~

输出目录 `scratch/dataset/CLB-SWE-bench/` 包含 `test.parquet`、发布用的
`eval.yaml` 和数据集卡片。[评测配置](../eval/CLB-SWE-bench.yaml) · [数据集卡片](../docs/dataset-card.md)

旧版迁移和三题历史复测见[归档说明](archive/README.md)。
CLB 实例 ID 采用 `<owner>__<repo>-clb-<原案例号>`。历史结果可通过[新旧 ID 对照表](archive/fixtures/instance-id-map.tsv)查找。
