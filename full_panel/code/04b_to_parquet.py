"""从 full_panel.dta 生成 full_panel.parquet（给 Python、R 或 AI 工具用，文件小、读得快）。

用法（在 full_panel 文件夹里）：
    python3 code/04b_to_parquet.py data/clean/full_panel.dta data/clean/full_panel.parquet

- 有值标签的变量（rel、pt_types）存成文字
- 年月、日期存成日期（年月是当月 1 号）
- 缺失值为空；含缺失值的整数变量会变成小数类型（pandas 的规则）
需要：pandas、pyarrow
"""
import sys

import pandas as pd

src, dst = sys.argv[1], sys.argv[2]
df = pd.read_stata(src, convert_categoricals=True, convert_dates=True)
df.to_parquet(dst, index=False)
print(f"{dst}: {len(df):,} 行 x {df.shape[1]} 列")
