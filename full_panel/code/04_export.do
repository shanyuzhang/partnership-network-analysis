* ==========================================================================================
* 04_export.do —— 导出 CSV 和变量说明表（给 Python、R、Excel 或 AI 工具用）
*
* 输入：$CLEAN/full_panel.dta
* 输出：$CLEAN/full_panel.csv            同样的数据：UTF-8、逗号分隔、第一行是变量名；rel、pt_types 写成文字，
*                                        年月写成 2018-07，日期写成 2018-07-06，缺失值为空
*       $CLEAN/full_panel_codebook.csv   变量说明表：变量名、Stata 存储类型、中文说明、英文说明
*       （Parquet 版本由 04b_to_parquet.py 从 full_panel.dta 生成）
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l04
log using "$OUT/logs/04_export.log", replace text name(l04)

use "$CLEAN/full_panel.dta", clear
format t run_start run_end fem %tmCCYY-NN
format listd %tdCCYY-NN-DD
export delimited using "$CLEAN/full_panel.csv", replace
di as txt "full_panel.csv：" _N " 行，" c(k) " 列"

* ---- 变量说明表 ----
tempname fh
file open `fh' using "$CLEAN/full_panel_codebook.csv", write replace text
file write `fh' "variable,stata_type,label_zh,description_en" _n
foreach v of varlist _all {
    local ty : type `v'
    local lz : variable label `v'
    local le : char `v'[en]
    file write `fh' `"`v',`ty',"`lz'","`le'""' _n
}
file close `fh'
di as txt "full_panel_codebook.csv：" c(k) " 个变量"

log close l04
