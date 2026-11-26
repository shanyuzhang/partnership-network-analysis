* ==========================================================================================
* 09_extrapolation.do —— 外推：Post x Impact x X 不中心化时，Post x Impact 的系数是“X = 0 时的效应”
*
* 背景：replication_jjyj2024 表 2 的 Post x Impact 显著，来自 10 个不中心化的 Post x 财务变量交互项：
*   处理组企业越大，冲击后断裂增加得越少，把 Size 外推到 0 就得到很大的正效应。这里看合作关系上
*   有没有同样靠外推得到的显著结果，不限于论文的那 10 个变量，正负都算。
*
* 输入：$CLEAN/analysis_sample.dta、analysis_K.dta、analysis_C.dta、analysis_M.dta（03 生成）
*       ../full_panel/data/clean/full_panel.dta：取伙伴 j 的 2017 年财务指标（size_j 等，本文件夹的回归样本
*       里没有）和每段关系的第一个月 run_start。没有这个文件时整个 09 跳过。
* 输出：$OUT/tables/extrap_sizej.csv、extrap_sizej.tex   主表：X = 伙伴规模 Size_j
*       $OUT/tables/extrap_age.csv                       同样五列：X = 关系已存在的月数
*       $OUT/tables/extrap_bins.csv                      不外推的核对：处理组冲击后按 X 分段，各段单独估
*       $OUT/tables/extrap_grid.csv                      试过的全部调节变量 x 三种固定效应
*       $OUT/tables/extrap_paperspec.csv                 论文表 2 的写法（i、j 各 5 个交互项）原样套用
*       $OUT/tables/extrap_sizej_fe.csv                  Size_j 外推用论文表 2 的四列固定效应；中心化、不加交互项对照
*       $OUT/tables/extrap_es.csv                        Size_j 外推的事件研究（论文式 (2)）
*       $OUT/figures/extrap_sig_all.png、extrap_sig_types.png   只画显著（p < 0.10）的 Post x Impact
*       表格的 PNG 由 09b_tables_png.py 生成（读这里和 ../replication_jjyj2024 的 07 的输出）
*
* 五列（与 04 主表同样的写法，再加论文表 2 的固定效应；标准误都按 A 股企业聚类）：
*   (1) break postimpact PX                            PX = postimpact x X，无固定效应
*   (2) (1) + postsize ... postgrowth                  再加 04 第 (2) 列的 5 个 A 股企业财务交互项
*   (3) (1) + 企业 x 月 FE
*   (4) (3) + us us_post us_tariff                     三重差分
*   (5) (1) + 关系对 FE + 月份 FE                      论文表 2 第 (1) 列的固定效应
*   每列另报“X 取处理组冲击后均值时的效应”= b + g x 均值（lincom），它和不加交互项的平均效应接近。
*
* Size_j = ln(伙伴 2017 年总资产美元 / 1000 万)，在样本上按观测 1%/99% 缩尾；Size_j = 0 即总资产 1000 万美元。
* age = t - run_start：这一段关系到当月已存在的月数（run_start = 2016m1 的段可能更早开始，按 2016m1 算）。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l09
log using "$OUT/logs/09_extrapolation.log", replace text name(l09)

local fp "$REPO/../full_panel/data/clean/full_panel.dta"
capture confirm file "`fp'"
if _rc {
    di as txt "没有找到完整面板 `fp'，跳过 09"
    log close l09
    exit
}

* ---- 伙伴 j 的 2017 年财务指标（每个 partner 一个值）和每段关系的 run_start ----
use rel partner size_j lev_j roa_j ato_j growth_j xj if rel == 3 using "`fp'", clear
bysort partner (size_j): keep if _n == 1
tempfile pj
save `pj'
use focal partner t run_start s_pt if s_pt == 1 using "`fp'", clear
tempfile rs
save `rs'

local Xi "postsize postlev postroa postato postgrowth"

* 一个样本上跑五列，写进 postfile
capture program drop _five
program define _five
    * 参数：postfile 句柄、样本名、X 的名字、交互项变量、X 变量
    args P grp xname PX x
    local Xi "postsize postlev postroa postato postgrowth"
    forvalues c = 1/5 {
        if `c' == 1 local cmd "reghdfe break postimpact `PX', noabsorb"
        if `c' == 2 local cmd "reghdfe break postimpact `PX' `Xi', noabsorb"
        if `c' == 3 local cmd "reghdfe break postimpact `PX', absorb(firm_m)"
        if `c' == 4 local cmd "reghdfe break postimpact `PX' us us_post us_tariff, absorb(firm_m)"
        if `c' == 5 local cmd "reghdfe break postimpact `PX', absorb(pid t)"
        capture quietly `cmd' vce(cluster focal)
        if _rc continue
        local N = e(N)
        local df = e(df_r)
        local b = _b[postimpact]
        local sb = _se[postimpact]
        local g = _b[`PX']
        local sg = _se[`PX']
        quietly summarize `x' if postimpact == 1 & e(sample)
        local mx = r(mean)
        local mn = r(min)
        quietly lincom postimpact + `mx' * `PX'
        local bm = r(estimate)
        local sm = r(se)
        post `P' ("`grp'") ("`xname'") (`c') (`N') (`b') (`sb') (2*ttail(`df', abs(`b'/`sb'))) ///
            (`g') (`sg') (2*ttail(`df', abs(`g'/`sg'))) (`mx') (`mn') (`bm') (`sm') (2*ttail(`df', abs(`bm'/`sm')))
    }
end

* ==========================================================================================
* 1. 全部合作关系：准备调节变量
* ==========================================================================================
use "$CLEAN/analysis_sample.dta", clear
merge m:1 partner using `pj', keep(master match) nogenerate
merge 1:1 focal partner t using `rs', assert(match) nogenerate
gen double age = t - run_start
bysort focal: egen int deg_i = nvals(partner)
bysort partner: egen int deg_j = nvals(focal)
gen double ldeg_i = ln(deg_i)
gen double ldeg_j = ln(deg_j)
bysort focal: egen double usshr_i = mean(us)
gen double evt = cond(postimpact == 1, t - fem, 0)
label var age     "关系已存在的月数"
label var evt     "冲击后第几个月（0 = 生效当月）"
label var ldeg_i  "ln(A 股企业的伙伴数)"
label var ldeg_j  "ln(伙伴的 A 股企业数)"
label var usshr_i "A 股企业的伙伴中美国企业的比例"
* 固定排序：merge、bysort 之后的顺序不固定，会让 reghdfe 的结果在很后面的小数位上不同
sort pid t
tempfile all
save `all'

tempname P
postfile `P' str4 grp str8 x byte col long N double b se p g gse gp mean_x min_x b_mean se_mean p_mean ///
    using "$OUT/tables/_extrap_five.dta", replace

* ---- X = Size_j（只用伙伴有 Size_j 的观测；在这个样本上缩尾） ----
use `all', clear
keep if size_j < .
quietly _pctile size_j, p(1 99)
gen double w_size_j = min(max(size_j, r(r1)), r(r2))
gen double PX = postimpact * w_size_j
_five `P' ALL size_j PX w_size_j
* 分段核对：处理组冲击后按 Size_j 四分位
xtile q = w_size_j if postimpact == 1, nq(4)
tempname B
postfile `B' str8 x byte bin double lo hi long nobs byte col double b se p using "$OUT/tables/_extrap_bins.dta", replace
forvalues k = 1/4 {
    gen byte Q`k' = postimpact == 1 & q == `k'
}
forvalues c = 1/2 {
    if `c' == 1 quietly reghdfe break Q1 Q2 Q3 Q4, noabsorb vce(cluster focal)
    else        quietly reghdfe break Q1 Q2 Q3 Q4, absorb(pid t) vce(cluster focal)
    local df = e(df_r)
    forvalues k = 1/4 {
        quietly summarize w_size_j if q == `k' & e(sample)
        post `B' ("size_j") (`k') (r(min)) (r(max)) (r(N)) (cond(`c' == 1, 1, 5)) (_b[Q`k']) (_se[Q`k']) ///
            (2*ttail(`df', abs(_b[Q`k']/_se[Q`k'])))
    }
}
* 第 (1) 列的三大类
foreach g in K C M {
    use "$CLEAN/analysis_`g'.dta", clear
    merge m:1 partner using `pj', keep(master match) nogenerate
    sort pid t
    keep if size_j < .
    quietly _pctile size_j, p(1 99)
    gen double w_size_j = min(max(size_j, r(r1)), r(r2))
    gen double PX = postimpact * w_size_j
    _five `P' `g' size_j PX w_size_j
}

* ---- X = age（全部观测） ----
use `all', clear
gen double PX = postimpact * age
_five `P' ALL age PX age
gen byte ab = cond(age < 6, 1, cond(age < 12, 2, cond(age < 24, 3, 4))) if postimpact == 1
forvalues k = 1/4 {
    gen byte A`k' = postimpact == 1 & ab == `k'
}
local lo1 0
local hi1 5
local lo2 6
local hi2 11
local lo3 12
local hi3 23
local lo4 24
local hi4 999
forvalues c = 1/2 {
    if `c' == 1 quietly reghdfe break A1 A2 A3 A4, noabsorb vce(cluster focal)
    else        quietly reghdfe break A1 A2 A3 A4, absorb(pid t) vce(cluster focal)
    local df = e(df_r)
    forvalues k = 1/4 {
        quietly count if A`k' == 1 & e(sample)
        quietly summarize age if ab == `k' & e(sample)
        post `B' ("age") (`k') (r(min)) (r(max)) (r(N)) (cond(`c' == 1, 1, 5)) (_b[A`k']) (_se[A`k']) ///
            (2*ttail(`df', abs(_b[A`k']/_se[A`k'])))
    }
}
postclose `B'

* ---- 其余调节变量：只放进 extrap_grid（(1)、(3)、(5) 三列） ----
use `all', clear
* w_size_i：analysis_sample.dta 里已有（回归样本上 1%/99% 缩尾）
foreach x in w_size_i evt ldeg_i ldeg_j usshr_i {
    gen double PX = postimpact * `x'
    _five `P' ALL `x' PX `x'
    drop PX
}
postclose `P'

* ==========================================================================================
* 2. 论文表 2 的写法原样套用：pid + 月份 FE 起，i、j 各 5 个交互项，按关系对聚类；要求 j 的财务指标齐全
* ==========================================================================================
tempname Q
postfile `Q' str4 grp byte col long N int ntr double b se p b_mean se_mean p_mean using "$OUT/tables/_extrap_paper.dta", replace
foreach g in sample K C M {
    use "$CLEAN/analysis_`g'.dta", clear
    merge m:1 partner using `pj', keep(master match) nogenerate
    sort pid t
    keep if xj == 1
    foreach v in size lev roa ato growth {
        foreach k in i j {
            quietly _pctile `v'_`k', p(1 99)
            gen double v_`v'_`k' = min(max(`v'_`k', r(r1)), r(r2))
            gen double PX_`v'_`k' = postimpact * v_`v'_`k'
        }
    }
    local ctl "PX_size_i PX_lev_i PX_roa_i PX_ato_i PX_growth_i PX_size_j PX_lev_j PX_roa_j PX_ato_j PX_growth_j"
    egen byte tp = tag(pid) if impact == 1
    quietly count if tp == 1
    local ntr = r(N)
    local fe1 "pid t"
    local fe2 "pid t sic#year"
    local fe3 "pid t sic#year focal#year"
    local fe4 "pid t sic#year focal#year partner#year"
    forvalues c = 1/4 {
        quietly reghdfe break postimpact `ctl', absorb(`fe`c'') vce(cluster pid)
        local df = e(df_r)
        local b = _b[postimpact]
        local sb = _se[postimpact]
        local lc "postimpact"
        foreach v of local ctl {
            local w = subinstr("`v'", "PX_", "v_", 1)
            quietly summarize `w' if postimpact == 1 & e(sample)
            local lc "`lc' + `r(mean)' * `v'"
        }
        quietly lincom `lc'
        local gname = cond("`g'" == "sample", "ALL", "`g'")
        post `Q' ("`gname'") (`c') (e(N)) (`ntr') (`b') (`sb') (2*ttail(`df', abs(`b'/`sb'))) ///
            (r(estimate)) (r(se)) (2*ttail(`df', abs(r(estimate)/r(se))))
    }
}
postclose `Q'

* ==========================================================================================
* 3. 输出
* ==========================================================================================
use "$OUT/tables/_extrap_five.dta", clear
format b se g gse mean_x min_x b_mean se_mean %9.4f
format p gp p_mean %6.3f
export delimited using "$OUT/tables/extrap_grid.csv", replace
di as txt _n "===== 试过的全部调节变量（b、p：X = 0 时的效应；b_mean：X 取处理组冲击后均值时的效应）====="
list grp x col N b p g gp mean_x min_x b_mean p_mean, noobs sepby(grp x) abbreviate(6)
preserve
keep if grp == "ALL" & x == "size_j"
export delimited using "$OUT/tables/extrap_sizej.csv", replace
restore
preserve
keep if grp == "ALL" & x == "age"
export delimited using "$OUT/tables/extrap_age.csv", replace
restore

* extrap_sizej.tex
keep if grp == "ALL" & x == "size_j"
sort col
tempname h
file open `h' using "$OUT/tables/extrap_sizej.tex", write replace text
file write `h' "\begin{tabular}{lccccc}" _n "\toprule" _n " & (1) & (2) & (3) & (4) & (5) \\" _n "\midrule" _n
foreach r in b g b_mean {
    if "`r'" == "b"      local lab "Post \(\times\) Impact"
    if "`r'" == "g"      local lab "Post \(\times\) Impact \(\times\) Size\textsubscript{j}"
    if "`r'" == "b_mean" local lab "Effect at mean Size\textsubscript{j}"
    local sr = cond("`r'" == "b", "se", cond("`r'" == "g", "gse", "se_mean"))
    local pr = cond("`r'" == "b", "p", cond("`r'" == "g", "gp", "p_mean"))
    file write `h' "`lab'"
    forvalues i = 1/5 {
        local st = cond(`pr'[`i'] < 0.01, "***", cond(`pr'[`i'] < 0.05, "**", cond(`pr'[`i'] < 0.10, "*", "")))
        file write `h' " & " %7.4f (`r'[`i']) "`st'"
    }
    file write `h' " \\" _n
    forvalues i = 1/5 {
        file write `h' " & (" %6.4f (`sr'[`i']) ")"
    }
    file write `h' " \\" _n
}
file write `h' "\midrule" _n "Firm \(\times\) month FE & No & No & Yes & Yes & No \\" _n ///
    "Pair FE, month FE & No & No & No & No & Yes \\" _n "Observations"
forvalues i = 1/5 {
    file write `h' " & " %9.0fc (N[`i'])
}
file write `h' " \\" _n "\bottomrule" _n "\end{tabular}" _n
file close `h'

use "$OUT/tables/_extrap_bins.dta", clear
format lo hi b se %9.4f
format p %6.3f
export delimited using "$OUT/tables/extrap_bins.csv", replace
di as txt _n "===== 分段核对（col 1：无固定效应；col 5：关系对 + 月份 FE）====="
list, noobs sepby(x col) abbreviate(6)

use "$OUT/tables/_extrap_paper.dta", clear
format b se b_mean se_mean %9.4f
format p p_mean %6.3f
export delimited using "$OUT/tables/extrap_paperspec.csv", replace
di as txt _n "===== 论文表 2 的写法（b：所有交互项变量 = 0 时；b_mean：都取处理组冲击后均值时）====="
list, noobs sepby(grp) abbreviate(6)

* ==========================================================================================
* 4. Size_j 外推用论文表 2 的固定效应写法；中心化和不加交互项对照
*    s = 0：无固定效应，按 A 股企业聚类（同上面第 (1) 列）；s = 1-4：论文表 2 的四列固定效应，按关系对聚类
* 5. 事件研究（论文式 (2)，同 06）：相对月份 x 处理组 x Size_j 不中心化 / 中心化 / 不加 / 不中心化再加 A 股企业 5 项
* ==========================================================================================
tempname F E
postfile `F' str4 grp str5 spec byte s long N int ntr double b se p g gse gp mean_x b_mean se_mean p_mean ///
    using "$OUT/tables/_extrap_fe.dta", replace
postfile `E' str4 grp str8 spec int k double b se pre_p post_p using "$OUT/tables/_extrap_es.dta", replace
local fe1 "pid t"
local fe2 "pid t sic#year"
local fe3 "pid t sic#year focal#year"
local fe4 "pid t sic#year focal#year partner#year"
local XI "w_size_i w_lev_i w_roa_i w_ato_i w_growth_i"
foreach g in sample K C M {
    local gn = cond("`g'" == "sample", "ALL", "`g'")
    use "$CLEAN/analysis_`g'.dta", clear
    merge m:1 partner using `pj', keep(master match) nogenerate
    sort pid t
    keep if size_j < .
    quietly _pctile size_j, p(1 99)
    gen double w_size_j = min(max(size_j, r(r1)), r(r2))
    gen double PX = postimpact * w_size_j
    quietly summarize w_size_j if postimpact == 1
    gen double CX = postimpact * (w_size_j - r(mean))
    quietly summarize w_size_j if impact == 1
    gen double c_size_j = w_size_j - r(mean)
    forvalues s = 0/4 {
        foreach sp in paper cen none {
            local rhs = cond("`sp'" == "paper", "postimpact PX", cond("`sp'" == "cen", "postimpact CX", "postimpact"))
            if `s' == 0 quietly reghdfe break `rhs', noabsorb vce(cluster focal)
            else        quietly reghdfe break `rhs', absorb(`fe`s'') vce(cluster pid)
            local df = e(df_r)
            local N = e(N)
            tempvar tg
            quietly egen byte `tg' = tag(pid) if e(sample) & impact == 1
            quietly count if `tg' == 1
            local ntr = r(N)
            drop `tg'
            local b = _b[postimpact]
            local se = _se[postimpact]
            local g2 = .
            local gse = .
            local m = .
            local bm = .
            local sm = .
            if "`sp'" == "paper" {
                local g2 = _b[PX]
                local gse = _se[PX]
                quietly summarize w_size_j if postimpact == 1 & e(sample)
                local m = r(mean)
                quietly lincom postimpact + `m' * PX
                local bm = r(estimate)
                local sm = r(se)
            }
            post `F' ("`gn'") ("`sp'") (`s') (`N') (`ntr') (`b') (`se') (2*ttail(`df', abs(`b'/`se'))) ///
                (`g2') (`gse') (2*ttail(`df', abs(`g2'/`gse'))) (`m') (`bm') (`sm') (2*ttail(`df', abs(`bm'/`sm')))
        }
    }
    * 事件研究
    gen int kk = max(min(t - fem, 6), -6) if impact == 1
    local Ev ""
    forvalues q = -6/6 {
        if `q' == -1 continue
        local nm = cond(`q' < 0, "m" + string(abs(`q')), "p" + string(`q'))
        gen byte E_`nm' = impact == 1 & kk == `q'
        local Ev "`Ev' E_`nm'"
    }
    foreach sp in paper cen none paperi5 {
        if "`sp'" == "paper"   local Xs "w_size_j"
        if "`sp'" == "cen"     local Xs "c_size_j"
        if "`sp'" == "none"    local Xs ""
        if "`sp'" == "paperi5" local Xs "w_size_j `XI'"
        local Kv ""
        foreach q of local Ev {
            foreach v of local Xs {
                gen double K`q'_`v' = `q' * `v'
                local Kv "`Kv' K`q'_`v'"
            }
        }
        quietly reghdfe break `Ev' `Kv', absorb(pid t) vce(cluster pid)
        quietly test E_m6 E_m5 E_m4 E_m3 E_m2
        local pre = r(p)
        quietly test E_p0 E_p1 E_p2 E_p3 E_p4 E_p5 E_p6
        local pst = r(p)
        forvalues q = -6/6 {
            if `q' == -1 {
                post `E' ("`gn'") ("`sp'") (`q') (0) (0) (`pre') (`pst')
                continue
            }
            local nm = cond(`q' < 0, "m" + string(abs(`q')), "p" + string(`q'))
            local bb = _b[E_`nm']
            local ss = _se[E_`nm']
            if `ss' == 0 {
                local bb = .
                local ss = .
            }
            post `E' ("`gn'") ("`sp'") (`q') (`bb') (`ss') (`pre') (`pst')
        }
        capture drop KE_*
    }
}
postclose `F'
postclose `E'
use "$OUT/tables/_extrap_fe.dta", clear
format b se g gse mean_x b_mean se_mean %9.4f
format p gp p_mean %6.3f
export delimited using "$OUT/tables/extrap_sizej_fe.csv", replace
di as txt _n "===== Size_j：论文表 2 的固定效应（s = 0 无固定效应）====="
list grp spec s N b p g gp b_mean p_mean if spec == "paper", noobs sepby(grp) abbreviate(6)
use "$OUT/tables/_extrap_es.dta", clear
format b se %9.4f
format pre_p post_p %6.3f
export delimited using "$OUT/tables/extrap_es.csv", replace
di as txt _n "===== Size_j 的事件研究：冲击前 / 冲击后联合检验 ====="
list grp spec pre_p post_p if k == -6, noobs sepby(grp)

* ==========================================================================================
* 6. 图：只画显著（p < 0.10）的 Post x Impact
*    来源：07 的三大类主表（types_main_reg.csv）、上面第 1 部分（extrap_grid.csv）、第 2 部分（extrap_paperspec.csv）
* ==========================================================================================
capture confirm file "$OUT/tables/types_main_reg.csv"
if !_rc {
    import delimited using "$OUT/tables/types_main_reg.csv", clear varnames(1) encoding(utf-8)
    rename typ grp
    keep grp col b se p
    gen str12 src = "main"
    tempfile mm
    save `mm'
}
import delimited using "$OUT/tables/extrap_grid.csv", clear varnames(1) encoding(utf-8)
keep grp x col b se p
rename x src
capture append using `mm'
tempfile gg
save `gg'
import delimited using "$OUT/tables/extrap_paperspec.csv", clear varnames(1) encoding(utf-8)
keep grp col b se p
gen str12 src = "paper10"
append using `gg'
keep if p < 0.10
* M 的 Size_j 第 (3)(4) 列：三重差分项共线被剔除，两列是同一个回归，只留 (3)
drop if grp == "M" & src == "size_j" & col == 4
gen lo95 = b - 1.96 * se
gen hi95 = b + 1.96 * se
gen lo90 = b - 1.645 * se
gen hi90 = b + 1.645 * se
gen str3 star = cond(p < 0.01, "***", cond(p < 0.05, "**", "*"))
gen str16 blab = string(b, "%6.4f") + star
gen str40 slab = ""
replace slab = "伙伴规模 Size_j 外推" if src == "size_j"
replace slab = "关系已存在月数外推" if src == "age"
replace slab = "论文写法 10 项交互" if src == "paper10"
replace slab = "主表（不外推）" if src == "main"
replace slab = src + " 外推" if slab == ""
gen str40 clab = ""
replace clab = "(1) 无固定效应" if src != "paper10" & col == 1
replace clab = "(2) + A 股企业财务交互项" if src != "paper10" & col == 2
replace clab = "(3) 企业×月 FE" if src != "paper10" & col == 3
replace clab = "(4) 企业×月 FE + 三重差分" if src != "paper10" & col == 4
replace clab = "(5) 关系对 + 月份 FE" if src != "paper10" & col == 5
replace clab = "(1) 关系对 + 月份 FE" if src == "paper10" & col == 1
replace clab = "(2) + 行业×年 FE" if src == "paper10" & col == 2
replace clab = "(3) + A 股企业×年 FE" if src == "paper10" & col == 3
replace clab = "(4) + 伙伴×年 FE" if src == "paper10" & col == 4
gen str80 lab = slab + "｜" + clab
gen byte so = cond(src == "main", 1, cond(src == "size_j", 2, cond(src == "age", 3, cond(src == "paper10", 5, 4))))
capture program drop _cplot
program define _cplot
    args g name ttl xt fy
    preserve
    keep if grp == "`g'"
    if _N == 0 {
        restore
        exit
    }
    gsort -so -col
    gen y = _n
    local n = _N
    local yl ""
    forvalues i = 1/`n' {
        local yl `"`yl' `i' "`=lab[`i']'""'
    }
    twoway (rspike lo95 hi95 y, horizontal lcolor(gs10) lwidth(medthin)) ///
           (rspike lo90 hi90 y, horizontal lcolor(navy) lwidth(thick)) ///
           (scatter y b, mcolor(navy) msymbol(D) msize(medsmall) mlabel(blab) mlabposition(12) mlabgap(1) ///
                mlabsize(vsmall) mlabcolor(black)), ///
        xline(0, lcolor(cranberry) lpattern(dash)) ///
        ylabel(`yl', angle(0) labsize(vsmall) nogrid) yscale(range(0.3 `=`n'+0.8')) ytitle("") ///
        xlabel(, labsize(vsmall)) xtitle("`xt'", size(vsmall)) legend(off) ///
        title("`ttl'", size(small) position(11) justification(left)) graphregion(color(white)) ///
        plotregion(margin(small)) name(`name', replace) `fy'
    restore
end
local xt "Post × Impact：粗线 90% 置信区间，细线 95%"
_cplot ALL gA "全部合作关系：显著的 Post × Impact（p < 0.10）" "`xt'" "ysize(3.2) xsize(8)"
graph export "$OUT/figures/extrap_sig_all.png", replace width(2000)
_cplot K gK "K 知识类" "" "fysize(34)"
_cplot C gC "C 资本类" "" "fysize(20)"
_cplot M gM "M 市场类（处理组关系对只有 18–33 个）" "`xt'；三个子图横轴刻度不同" "fysize(46)"
graph combine gK gC gM, cols(1) imargin(vsmall) graphregion(color(white)) ///
    title("三大类：显著的 Post × Impact（p < 0.10）", size(small)) xsize(8) ysize(10)
graph export "$OUT/figures/extrap_sig_types.png", replace width(2000)

erase "$OUT/tables/_extrap_fe.dta"
erase "$OUT/tables/_extrap_es.dta"

erase "$OUT/tables/_extrap_five.dta"
erase "$OUT/tables/_extrap_bins.dta"
erase "$OUT/tables/_extrap_paper.dta"
log close l09
