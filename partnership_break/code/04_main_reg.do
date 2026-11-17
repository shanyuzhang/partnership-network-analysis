* ==========================================================================================
* 04_main_reg.do —— 主回归：样本规模、主表四列
*
* 输入：$CLEAN/analysis_sample.dta（03 生成）
* 输出：$OUT/tables/table1_sample.csv       样本规模
*       $OUT/tables/main_reg.tex、main_reg.csv   主表四列
*
* 观测单位：A 股企业 i x 外国伙伴 j x 月，只用关系存在的月份（断裂当月保留，之后退出）
*   处理组：A 股企业所在行业被加征关税（tariff_i = 1）且伙伴是美国企业（us = 1），即 impact = 1
*   对照组：其余三格 —— 加征行业企业 x 其他外国伙伴；未加征企业 x 美国伙伴；未加征企业 x 其他外国伙伴
*   postimpact = post x impact（论文写法的 Post：只有处理组在本行业首次加征关税生效月及以后为 1）
*
*   (1) reghdfe break postimpact                                 只有 postimpact，无固定效应
*   (2) (1) + postsize postlev postroa postato postgrowth        《经济研究》写法的控制变量：postimpact x A 股企业
*                                                                2017 年 Size、Lev（债务/总资产）、ROA（小数）、
*                                                                ATO、Growth（样本内按观测 1%/99% 缩尾）
*   (3) reghdfe break postimpact, absorb(firm_m)                 只有 postimpact + 企业 x 月 FE：同一 A 股企业
*                                                                同一个月，美国伙伴 vs 其他外国伙伴
*   (4) (3) + us us_post us_tariff                               三重差分：再扣掉美国伙伴的一贯差距、
*                                                                冲击后所有企业共同的美国伙伴变化、
*                                                                加征关税企业本来就有的美国伙伴差距
*   标准误：四列都按 A 股企业聚类
*
*   注意：postimpact x X 只在处理组冲击后不为 0，所以第 (2) 列 postimpact 的系数是“X 全部等于 0”时的效应
*   （与论文的写法相同）。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l04
log using "$OUT/logs/04_main_reg.log", replace text name(l04)

use "$CLEAN/analysis_sample.dta", clear

* ==========================================================================================
* 1. 样本规模
* ==========================================================================================
egen byte tf = tag(focal)
egen byte tc = tag(partner)
egen byte tp = tag(pid)
tempname h
file open `h' using "$OUT/tables/table1_sample.csv", write replace text
file write `h' "item,value" _n
quietly count if tf == 1
file write `h' "A 股企业数," (r(N)) _n
quietly count if tc == 1
file write `h' "外国伙伴数," (r(N)) _n
quietly count if tc == 1 & us
file write `h' "其中美国伙伴," (r(N)) _n
quietly count if tp == 1
file write `h' "关系对数," (r(N)) _n
quietly count if tp == 1 & impact
file write `h' "其中处理组关系对（Impact = 1）," (r(N)) _n
quietly count
file write `h' "关系对 x 月," (r(N)) _n
quietly count if break
file write `h' "断裂次数," (r(N)) _n
quietly summarize break
file write `h' "Break 均值," %6.4f (r(mean)) _n
quietly summarize impact if tp == 1
file write `h' "Impact 均值（关系对层面）," %6.4f (r(mean)) _n
file close `h'
type "$OUT/tables/table1_sample.csv"
di as txt _n "关系对按处理格（行 tariff_i：A 股企业行业是否加征关税；列 us：伙伴是否美国企业）"
tab tariff_i us if tp == 1
di as txt _n "各格的月均断裂率（冲击前 / 后）"
table (tariff_i us) (post), statistic(mean break) statistic(count break) nformat(%9.4f mean)
di as txt _n "控制变量（A 股企业，每家一次；样本内按观测缩尾后的值）"
tabstat w_size_i w_lev_i w_roa_i w_ato_i w_growth_i if tf == 1, statistics(n mean sd min max) columns(statistics) format(%8.3f)
drop tf tc tp

* ==========================================================================================
* 2. 主表
* ==========================================================================================
* 处理组关系对数（回归样本里 Impact = 1 的关系对）
capture program drop _ntr
program define _ntr
    tempvar tg
    quietly egen byte `tg' = tag(pid) if e(sample) & impact == 1
    quietly count if `tg' == 1
    estadd scalar ntr = r(N)
end

local X "postsize postlev postroa postato postgrowth"
label var postimpact "Post x Impact"
label var us         "US partner"
label var us_post    "US x Post"
label var us_tariff  "US x Tariff"
eststo clear
* (1) 只有 postimpact
eststo r1: reghdfe break postimpact, noabsorb vce(cluster focal)
_ntr
estadd local fe_fm "No"
* (2) postimpact + 财务变量
eststo r2: reghdfe break postimpact `X', noabsorb vce(cluster focal)
_ntr
estadd local fe_fm "No"
* (3) 只有 postimpact + 企业 x 月 FE
eststo r3: reghdfe break postimpact, absorb(firm_m) vce(cluster focal)
_ntr
estadd local fe_fm "Yes"
* (4) 三重差分
eststo r4: reghdfe break postimpact us us_post us_tariff, absorb(firm_m) vce(cluster focal)
_ntr
estadd local fe_fm "Yes"

di as txt _n "===== 主表：合作关系（标准误按 A 股企业聚类）====="
esttab r1 r2 r3 r4, b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) label ///
    order(postimpact us us_post us_tariff `X') ///
    stats(fe_fm N ntr r2, labels("企业 x 月 FE" "观测值" "处理组关系对" "R2") fmt(%s %9.0fc %9.0fc %9.4f)) ///
    mtitles("Break" "Break" "Break" "Break") modelwidth(12) varwidth(30) nonotes
esttab r1 r2 r3 r4 using "$OUT/tables/main_reg.tex", replace b(%9.4f) se(%9.4f) ///
    star(* 0.10 ** 0.05 *** 0.01) booktabs ///
    varlabels(postimpact "Post \(\times\) Impact" us "US partner" us_post "US \(\times\) Post" ///
        us_tariff "US \(\times\) Tariff" postsize "Post \(\times\) Impact \(\times\) Size" ///
        postlev "Post \(\times\) Impact \(\times\) Lev" postroa "Post \(\times\) Impact \(\times\) ROA" ///
        postato "Post \(\times\) Impact \(\times\) ATO" postgrowth "Post \(\times\) Impact \(\times\) Growth" ///
        _cons "Constant") ///
    order(postimpact us us_post us_tariff `X') ///
    stats(fe_fm N ntr r2, labels("Firm \(\times\) month FE" "Observations" "Treated pairs" "R\(^2\)") fmt(%s %9.0fc %9.0fc %9.4f)) ///
    mtitles("Break" "Break" "Break" "Break") ///
    addnotes("A-share firm x foreign partner x month, 2017m1-2019m12. Standard errors clustered by A-share firm." ///
        "Column (2) controls: Post \(\times\) Impact \(\times\) 2017 Size, Lev (debt/assets), ROA, ATO and Growth of the A-share firm," ///
        "winsorized at 1\%/99\% within the sample.")
esttab r1 r2 r3 r4 using "$OUT/tables/main_reg.csv", replace csv plain b(%9.4f) se(%9.4f) ///
    star(* 0.10 ** 0.05 *** 0.01) label order(postimpact us us_post us_tariff `X') ///
    stats(fe_fm N ntr r2, labels("Firm x month FE" "N" "Treated pairs" "R2") fmt(%s %9.0f %9.0f %9.4f)) ///
    mtitles("(1)" "(2)" "(3)" "(4)") nonumbers nonotes

log close l04
