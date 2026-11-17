* ==========================================================================================
* 05_figure1.do —— 论文图 1：中美企业跨国供应链断裂比例的月度变化
*
* 输入：$CLEAN/panel_monthly.dta（03 生成；2017m1-2020m6，已做全部样本筛选）
* 输出：$OUT/figures/figure1_break_share.png
*       $OUT/tables/figure1_break_share.csv   每月的断裂比例（%）
*
* 做法：只看美国客户，每个月断裂的关系对数 / 当月存在的关系对数，2018 年 1 月到 2020 年 6 月。
*       竖线是四轮加征关税的生效月份（2018 年 7、8、9 月和 2019 年 9 月）。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l05
log using "$OUT/logs/05_figure1.log", replace text name(l05)

use "$CLEAN/panel_monthly.dta", clear
keep if us == 1
collapse (mean) share = break (count) n = break, by(t)
replace share = 100 * share
keep if inrange(t, tm(2018m1), tm(2020m6))
format share %5.2f
list t n share, noobs sep(6)
export delimited t n share using "$OUT/tables/figure1_break_share.csv", replace

local l7  = tm(2018m7)
local l8  = tm(2018m8)
local l9  = tm(2018m9)
local l19 = tm(2019m9)
twoway (connected share t, lcolor(black) lpattern(dash) mcolor(black) msymbol(Oh)), ///
       xline(`l7' `l8' `l9' `l19', lcolor(gs8) lpattern(dot)) ///
       text(13.5 `l7' "2018年7月", place(w) size(small)) text(14.3 `l8' "2018年8月", size(small)) ///
       text(13.5 `l9' "2018年9月", place(e) size(small)) text(13.5 `l19' "2019年9月", place(w) size(small)) ///
       xlabel(`=tm(2018m1)' "2018年1月" `=tm(2018m7)' "2018年7月" `=tm(2019m1)' "2019年1月" ///
              `=tm(2019m7)' "2019年7月" `=tm(2020m1)' "2020年1月" `=tm(2020m6)' "2020年6月", labsize(small)) ///
       xscale(range(`=tm(2017m12)' `=tm(2020m7)')) ylabel(0(2)14, angle(0) format(%3.0f)) yscale(range(0 14.5)) ///
       ytitle("跨国供应链断裂比例（%）", margin(r=4)) xtitle("时间") legend(off) ///
       graphregion(color(white)) plotregion(color(white)) xsize(9) ysize(5.5)
graph export "$OUT/figures/figure1_break_share.png", replace width(1800)

log close l05
