# CLB 任务维护

以下命令从任务仓库根目录运行。依赖安装见[仓库首页](../README.md#安装和生成)。
原有的 `clb-dockerfile-gen` 和 `python -m dockerfile_gen` 也可以调用生成器。

## 导出数据

~~~bash
swebench dataset check .
swebench dataset build . -o scratch/dataset
cp docs/dataset-card.md scratch/dataset/CLB-SWE-bench/README.md
~~~

输出目录 `scratch/dataset/CLB-SWE-bench/` 包含 `test.parquet`、发布用的
`eval.yaml` 和数据集卡片。[评测配置](../eval/CLB-SWE-bench.yaml) · [数据集卡片](../docs/dataset-card.md)

## 复测历史结果

先构建三题的评测镜像，再运行 Base、Gold 和历史模型补丁对照。

~~~bash
swebench images build . --namespace swebench -j 1 \
  -i scipy__scipy-clb-002 -i ninia__jep-clb-093 -i kohlschutter__junixsocket-clb-175
python tools/verify_pilot.py --output scratch --run-id clb-pilot
~~~

结果写入 `scratch/clb-pilot-comparison.json`。要开始新的复测，请使用新的 `--run-id`。
中断后可用原 `--run-id` 加 `--resume` 继续。同一组镜像的构建和对照依次执行，构建会更新标签。
历史候选的来源、镜像版本和补丁哈希见[复测记录](fixtures/provenance.json)。

## 核对旧数据迁移

持有旧冻结发布仓库的维护者可用下面的命令核对导入文件。

~~~bash
python tools/import_frozen_tasks.py ../CLB-SWE-bench-v1 --check
~~~

CLB 实例 ID 采用 `<owner>__<repo>-clb-<原案例号>`。历史结果可通过[新旧 ID 对照表](fixtures/instance-id-map.tsv)查找。
