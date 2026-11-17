* ==========================================================================================
* 04_table2.do —— 回归：论文表 1 的样本对照、表 2（基准回归）、附表 3 第 (1)-(4) 列
*
* 输入：$CLEAN/analysis_sample.dta（03 生成）
* 输出：$OUT/tables/table1_sample.csv        样本规模与控制变量描述统计
*       $OUT/tables/table2.tex、table2.csv   表 2 四列
*       $OUT/tables/appendix_table3.tex、.csv 附表 3 第 (1)-(4) 列
*
* 论文式 (1)：Break_ijt = b Post x Impact + Σ Post x X_i + Σ Post x X_j + 年月 FE + 关系对 FE
*   Post 只对处理组冲击后为 1，所以 Post x Impact = Post，控制变量 = Post x X（X 为两边 2017 年特征，已缩尾）。
*   表 2 四列的固定效应：(1) 关系对 + 年月；(2) + 供应商行业 x 年；(3) + 供应商企业 x 年；(4) + 客户企业 x 年。
*   标准误按关系对聚类。
* 附表 3：第 (1)-(3) 列因变量换成 Break1、Break2、Break3；第 (4) 列论文写的是“排除新冠疫情的影响”
*   （N = 58,339），原文没有说明具体怎么做，这里用截至 2019 年 3 月的样本。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l04
log using "$OUT/logs/04_table2.log", replace text name(l04)

use "$CLEAN/analysis_sample.dta", clear

* ==========================================================================================
* 1. 样本规模与描述统计（对照论文表 1）
* ==========================================================================================
egen byte tf = tag(focal)
egen byte tc = tag(partner)
egen byte tp = tag(pid)
tempname h
file open `h' using "$OUT/tables/table1_sample.csv", write replace text
file write `h' "item,ours,paper" _n
quietly count if tf
file write `h' "中国供应商数," (r(N)) ",1001" _n
quietly count if tc
file write `h' "外国客户数," (r(N)) ",1546" _n
quietly count if tp
file write `h' "关系对数," (r(N)) ",4989" _n
quietly count
file write `h' "关系对 x 月," (r(N)) ",83946" _n
quietly summarize break
file write `h' "Break 均值," %6.4f (r(mean)) ",0.0261" _n
quietly summarize impact if tp
file write `h' "Impact 均值（关系对层面）," %6.4f (r(mean)) ",0.176" _n
file close `h'
type "$OUT/tables/table1_sample.csv"
di as txt _n "控制变量（中国供应商，每家一次；论文表 1：Size_i 4.443，Lev_i 0.210，ROA_i 0.0525，ATO_i 0.625，Growth_i 0.341）"
tabstat w_size_i w_lev_i w_roa_i w_ato_i w_growth_i if tf, statistics(n mean sd min max) columns(statistics) format(%8.3f)
di as txt "控制变量（外国客户，每家一次；论文表 1：Size_j 5.973，Lev_j 0.263，ROA_j 0.0438，ATO_j 0.905，Growth_j 0.0787）"
tabstat w_size_j w_lev_j w_roa_j w_ato_j w_growth_j if tc, statistics(n mean sd min max) columns(statistics) format(%8.3f)
drop tf tc tp

* ==========================================================================================
* 2. 表 2
* ==========================================================================================
foreach v in size lev roa ato growth {
    foreach k in i j {
        gen double PX_`v'_`k' = Post * w_`v'_`k'
    }
}
label var Post        "Post×Impact"
label var PX_size_i   "Post×Size_i"
label var PX_lev_i    "Post×Lev_i"
label var PX_roa_i    "Post×ROA_i"
label var PX_ato_i    "Post×ATO_i"
label var PX_growth_i "Post×Growth_i"
label var PX_size_j   "Post×Size_j"
label var PX_lev_j    "Post×Lev_j"
label var PX_roa_j    "Post×ROA_j"
label var PX_ato_j    "Post×ATO_j"
label var PX_growth_j "Post×Growth_j"
local ctl "PX_size_i PX_lev_i PX_roa_i PX_ato_i PX_growth_i PX_size_j PX_lev_j PX_roa_j PX_ato_j PX_growth_j"
local fe1 "pid t"
local fe2 "pid t sic#year"
local fe3 "pid t sic#year focal#year"
local fe4 "pid t sic#year focal#year partner#year"

eststo clear
forvalues c = 1/4 {
    eststo t2_`c': reghdfe break Post `ctl', absorb(`fe`c'') vce(cluster pid)
    local y2 = cond(`c' >= 2, "Yes", "No")
    local y3 = cond(`c' >= 3, "Yes", "No")
    local y4 = cond(`c' >= 4, "Yes", "No")
    estadd local fe_sic  "`y2'"
    estadd local fe_firm "`y3'"
    estadd local fe_cust "`y4'"
}
di as txt _n "===== 表 2（论文：0.127*** (0.0307)、0.116*** (0.0324)、0.100*** (0.0341)、0.141*** (0.0435)）====="
esttab t2_*, b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label order(Post `ctl') ///
    stats(N r2 fe_sic fe_firm fe_cust, fmt(%9.0fc %9.3f) labels("观测值" "R2" "供应商行业×年份 FE" "供应商企业×年份 FE" "客户企业×年份 FE")) ///
    mtitles("(1)" "(2)" "(3)" "(4)") nonumbers modelwidth(11) varwidth(22) nonotes
local texlab `"Post "Post \(\times\) Impact" PX_size_i "Post \(\times\) Size\textsubscript{i}" PX_lev_i "Post \(\times\) Lev\textsubscript{i}" PX_roa_i "Post \(\times\) ROA\textsubscript{i}" PX_ato_i "Post \(\times\) ATO\textsubscript{i}" PX_growth_i "Post \(\times\) Growth\textsubscript{i}" PX_size_j "Post \(\times\) Size\textsubscript{j}" PX_lev_j "Post \(\times\) Lev\textsubscript{j}" PX_roa_j "Post \(\times\) ROA\textsubscript{j}" PX_ato_j "Post \(\times\) ATO\textsubscript{j}" PX_growth_j "Post \(\times\) Growth\textsubscript{j}" _cons "Constant""'
esttab t2_* using "$OUT/tables/table2.tex", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    booktabs coeflabels(`texlab') order(Post `ctl') nomtitles numbers ///
    stats(N r2 fe_sic fe_firm fe_cust, fmt(%9.0fc %9.3f) labels("Observations" "R\(^2\)" "Supplier industry \(\times\) year FE" ///
        "Supplier \(\times\) year FE" "Customer \(\times\) year FE")) ///
    addnotes("Dependent variable: Break. All columns include pair FE and year-month FE; SE clustered by pair.")
esttab t2_* using "$OUT/tables/table2.csv", replace csv plain b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label order(Post `ctl') stats(N r2, fmt(%9.0f %9.3f)) mtitles("(1)" "(2)" "(3)" "(4)") nonumbers nonotes

* ==========================================================================================
* 3. 附表 3 第 (1)-(4) 列（固定效应同表 2 第 (1) 列）
* ==========================================================================================
eststo clear
eststo a3_1: reghdfe break1 Post `ctl', absorb(`fe1') vce(cluster pid)
eststo a3_2: reghdfe break2 Post `ctl', absorb(`fe1') vce(cluster pid)
eststo a3_3: reghdfe break3 Post `ctl', absorb(`fe1') vce(cluster pid)
eststo a3_4: reghdfe break  Post `ctl' if t <= tm(2019m3), absorb(`fe1') vce(cluster pid)
di as txt _n "===== 附表 3（论文：Break1 0.137*** (0.0279)；Break2 0.113*** (0.0256)；Break3 0.0628*** (0.0229)；第 (4) 列 0.124*** (0.0394)，N = 58,339）====="
esttab a3_*, b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label keep(Post) ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("观测值" "R2")) ///
    mtitles("Break1" "Break2" "Break3" "Break，截至2019m3") modelwidth(13) varwidth(14) nonotes
esttab a3_* using "$OUT/tables/appendix_table3.tex", replace b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    booktabs coeflabels(Post "Post \(\times\) Impact") keep(Post) mtitles("Break1" "Break2" "Break3" "Break") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R\(^2\)")) ///
    addnotes("Controls (Post x X) included; pair FE and year-month FE; SE clustered by pair." ///
             "Column (4): sample up to 2019m3 (the paper says it excludes COVID effects; the exact rule is not stated).")
esttab a3_* using "$OUT/tables/appendix_table3.csv", replace csv plain b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    label keep(Post) stats(N r2, fmt(%9.0f %9.3f)) mtitles("Break1" "Break2" "Break3" "Break_to2019m3") nonotes

log close l04
