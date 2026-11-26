* ==========================================================================================
* 07_extrapolation.do —— 表 2 的 Post × Impact 是外推出来的：中心化、固定效应、事件研究
*
* 输入：$CLEAN/analysis_sample.dta（03 生成）
* 输出：$OUT/tables/extrapolation.csv          表 2 四列：论文写法 / 中心化 / 不加交互项
*       $OUT/tables/extrapolation_decomp.csv   第 (1) 列的分解：lift = −γ × 处理组冲击后均值，即从均值外推到 0
*                                              时这一项给 Post 加上的部分；Post = 均值处的效应 + Σ lift
*       $OUT/tables/extrapolation_es.csv       附图 1（论文式 (2)）：论文写法 / 中心化 / 不加交互项
*       $OUT/figures/extrapolation_event_study.png  附图 1 的论文写法与中心化放在一起
*
* 论文写法：Break = a·Post + Σ b_k·Post × X_k + FE，X_k 不中心化，所以 a 是“10 个 X 都等于 0”时的效应。
*   Size = 0 是总资产 1000 万美元，远在样本之外，a 是沿直线外推出来的值。
* 中心化：X_k 换成 X_k − 处理组冲击后的均值（事件研究用处理组的均值），模型的拟合不变，
*   a 变成“X 取处理组均值时的效应”，与不加交互项的结果几乎一样。
* 固定效应、聚类与 04、06 相同（关系对 FE + 月份 FE 起逐列加；按关系对聚类）。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l07
log using "$OUT/logs/07_extrapolation.log", replace text name(l07)

use "$CLEAN/analysis_sample.dta", clear
sort pid t

local X10 ""
foreach v in size lev roa ato growth {
    foreach k in i j {
        local X10 "`X10' w_`v'_`k'"
    }
}
local PX ""
local CX ""
local cX ""
foreach v of local X10 {
    gen double PX_`v' = Post * `v'
    quietly summarize `v' if Post == 1
    gen double CX_`v' = Post * (`v' - r(mean))
    quietly summarize `v' if impact == 1
    gen double c_`v' = `v' - r(mean)
    local PX "`PX' PX_`v'"
    local CX "`CX' CX_`v'"
    local cX "`cX' c_`v'"
}
local fe1 "pid t"
local fe2 "pid t sic#year"
local fe3 "pid t sic#year focal#year"
local fe4 "pid t sic#year focal#year partner#year"

* ==========================================================================================
* 1. 表 2 四列：论文写法 / 中心化 / 不加交互项
* ==========================================================================================
tempname P D
postfile `P' str5 spec byte col long N double b se p using "$OUT/tables/_x.dta", replace
postfile `D' str12 x double mean_post g gse lift using "$OUT/tables/_d.dta", replace
forvalues c = 1/4 {
    foreach sp in paper cen none {
        if "`sp'" == "paper" quietly reghdfe break Post `PX', absorb(`fe`c'') vce(cluster pid)
        if "`sp'" == "cen"   quietly reghdfe break Post `CX', absorb(`fe`c'') vce(cluster pid)
        if "`sp'" == "none"  quietly reghdfe break Post, absorb(`fe`c'') vce(cluster pid)
        post `P' ("`sp'") (`c') (e(N)) (_b[Post]) (_se[Post]) (2*ttail(e(df_r), abs(_b[Post]/_se[Post])))
        if "`sp'" == "paper" & `c' == 1 {
            foreach v of local X10 {
                quietly summarize `v' if Post == 1 & e(sample)
                post `D' ("`v'") (r(mean)) (_b[PX_`v']) (_se[PX_`v']) (-_b[PX_`v'] * r(mean))
            }
        }
    }
}
postclose `P'
postclose `D'

* ==========================================================================================
* 2. 附图 1（论文式 (2)）：论文写法 / 中心化 / 不加交互项
* ==========================================================================================
tempname E
postfile `E' str5 spec int k double b se pre_p post_p using "$OUT/tables/_e.dta", replace
gen int kk = max(min(t - fem, 6), -6) if impact == 1
local Ev ""
forvalues q = -6/6 {
    if `q' == -1 continue
    local nm = cond(`q' < 0, "m" + string(abs(`q')), "p" + string(`q'))
    gen byte E_`nm' = impact == 1 & kk == `q'
    local Ev "`Ev' E_`nm'"
}
foreach sp in paper cen none {
    local Kv ""
    if "`sp'" != "none" {
        local Xs = cond("`sp'" == "paper", "`X10'", "`cX'")
        foreach q of local Ev {
            foreach v of local Xs {
                gen double K`q'_`v' = `q' * `v'
                local Kv "`Kv' K`q'_`v'"
            }
        }
    }
    quietly reghdfe break `Ev' `Kv', absorb(pid t) vce(cluster pid)
    quietly test E_m6 E_m5 E_m4 E_m3 E_m2
    local pre = r(p)
    quietly test E_p0 E_p1 E_p2 E_p3 E_p4 E_p5 E_p6
    local pst = r(p)
    di as txt "`sp'：冲击前 p = " %5.3f `pre' "，冲击后 p = " %5.3f `pst'
    forvalues q = -6/6 {
        if `q' == -1 {
            post `E' ("`sp'") (`q') (0) (0) (`pre') (`pst')
            continue
        }
        local nm = cond(`q' < 0, "m" + string(abs(`q')), "p" + string(`q'))
        post `E' ("`sp'") (`q') (_b[E_`nm']) (_se[E_`nm']) (`pre') (`pst')
    }
    capture drop KE_*
}
postclose `E'

* ==========================================================================================
* 3. 输出
* ==========================================================================================
use "$OUT/tables/_x.dta", clear
format b se %9.4f
format p %6.3f
list, noobs sepby(col)
export delimited using "$OUT/tables/extrapolation.csv", replace

use "$OUT/tables/_d.dta", clear
format mean_post g gse lift %9.4f
quietly summarize lift
di as txt "第 (1) 列：交互项一共把 Post 推高了 " %6.4f r(sum)
list, noobs
export delimited using "$OUT/tables/extrapolation_decomp.csv", replace

use "$OUT/tables/_e.dta", clear
format b se %9.4f
format pre_p post_p %6.3f
export delimited using "$OUT/tables/extrapolation_es.csv", replace
gen lo = b - 1.96 * se
gen hi = b + 1.96 * se
gen double kx = k + cond(spec == "paper", -0.12, cond(spec == "cen", 0.12, 0))
twoway (rcap lo hi kx if spec == "paper", lcolor(navy%60)) ///
       (connected b kx if spec == "paper", lcolor(navy) mcolor(navy) msymbol(O)) ///
       (rcap lo hi kx if spec == "cen", lcolor(cranberry%60)) ///
       (connected b kx if spec == "cen", lcolor(cranberry) mcolor(cranberry) msymbol(Dh) lpattern(dash)), ///
       yline(0, lcolor(gs8) lpattern(dash)) xline(-1, lcolor(gs8) lpattern(dash)) xlabel(-6(1)6) ///
       ylabel(, format(%3.2f) angle(0)) xtitle("距离美国贸易政策实施月份") ytitle("估计系数", margin(r=4)) ///
       legend(order(2 "论文写法：特征不中心化（X = 0 处）" 4 "特征在处理组均值处中心化") rows(1) position(6)) ///
       graphregion(color(white)) plotregion(color(white)) xsize(9) ysize(5.5)
graph export "$OUT/figures/extrapolation_event_study.png", replace width(1800)

erase "$OUT/tables/_x.dta"
erase "$OUT/tables/_d.dta"
erase "$OUT/tables/_e.dta"
log close l07
