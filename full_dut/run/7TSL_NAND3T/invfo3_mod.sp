*title ro_tran

*INFO

** Hspice options
*.option AUTOSTOP
*.option ACCURATE
*.option measdgt=5
*.option GMINDC=1e-18
*.option GMIN=1e-18
*.option INGOLD=1
*.option MEASFORM=2
*.option brief

*.option RUNLEVEL=3
*.option CSDF

.options brief runlvl=5 accurate tnom=25 dccap probe mcbrief=1 montecon measdgt=5 autostop

.prot
* Edit following line to point to directory with HSPICE model

* v0.2 final model release 
*.inc '/afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.2/Spice/design_include.inc'

* v0.22 final model release 
*.inc '/afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.22/Spice/design_include.inc'


* v0.5 early model release 4, same as 3 but with cov_tune parameter
*.inc '/afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251114/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251114/fixed_corner.lib TT

* v0.5 early model release 7
*.inc '/afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251203/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251203/fixed_corner.lib TT

* v0.5 early model release 8, updated SS vs. T dependence
*.inc '/afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251205/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251205/fixed_corner.lib TT

* v0.5 early model release 9, fixed ESPIN convergence issue
*.inc '/afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251210/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251210/fixed_corner.lib TT

* v0.51 early model release, with v0.5 patch material across all Vt flavors
*.inc '/afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.51/Spice.260107/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.51/Spice.260107/fixed_corner.lib TT

* v0.51 prod model
*.inc '/afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.51/Spice/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.51/Spice/fixed_corner.lib TT

* v0.51 prod model with rext tune added
*.inc '/afs/apd/ant/research/dev/2HP/V0.51/Spice-rext/design_include.inc'
*.lib /afs/apd/ant/research/dev/2HP/V0.51/Spice-rext/fixed_corner.lib TT

* v0.6SB2 model (v0.51 w/ 29.26 aF/um uplift plus dRint = -14 Ohm-um, Rext = -25 Ohm-um)
*.inc '/afs/apd/ant/research/test/2HP/v0.53/Spice-260604-sandbox/design_include.inc'
*.lib '/afs/apd/ant/research/test/2HP/v0.53/Spice-260604-sandbox/fixed_corner.lib TT'
.inc /afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/design_include.inc
.lib /afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/fixed_corner.lib TT

***Cgs adder in fF/um
*.param cov_tune = 0.02926

*.param rdext_tune = 100 $ in 0hm-um
*.param rsext_tune = 100 $ in 0hm-um

*.param shmod = 0
.param glles = 0
.param pre_layout_sw = 0
.param iddquplift = 0
.unprot



* g =   0.
* out = 1.198e-05
* vdd =   0.7500
* vss =   0.
* xro.pdd =   0.7500
* xro.pss = 6.411e-06
.prot

.temp 25
.param PVDD=0.70
.param PVDD2 = PVDD/2
.param PVSS  = 0
.param settle = 1n
.param STAGES = 101
.param periphery = 0


.inc  /gpfs/projects/t/titan/pdk/models/upl/2hp/cronus_dd1/PPG_RO_A13_PPG_Suite/netlists/v0.6.SB/A13_10_PPGSuite_NAND3_X1_T_45_7T_FO3_SLVT.spf'



VNW NW 0 PVDD
VS VSS 0 PVSS
VD VDD 0 PVDD
*VD VDD 0 PULSE     0          PVDD          '10p'              500p        500p            100n     200n
* Buffer VDD
VBVD BVD 0 PVDD


* Creat for netlist with PAD resistance w/o buffer vdd
**v0p2 arrangement ESPRO
**.SUBCKT RO RO_ENA LO HI RO_OUT

*v0p51 arrangement ESPRO
*.SUBCKT RO RO_ENA LO NW HI RO_OUT

*v0p51 arrangement ESPRO
.SUBCKT RO RO_ENA LO HI RO_OUT

**RSPAD LO PSS 7
**RDPAD HI PDD 7

RSPAD LO PSS 1a
RDPAD HI PDD 1a


****XRO1	EN PSS PDD PDD OUT PSS ESP4545_ROM1_A15_Ref_CP45_6p25T_Fanout3_working1

**v0p2 arrangement ESPRO
**  XRO1	RO_ENA PSS PDD RO_OUT A00_ESP_ROM1_A1_S03_edit

**v0p51 arrangement ESPRO
**  XRO1	RO_ENA PSS NW PDD RO_OUT SUBCKT_ESPRO

**v0p51 arrangement PPG
  XRO1	RO_ENA PSS PDD RO_OUT A13_D10_PPG_DUT


.ENDS RO                     $

**XRO VDD G VSS RO_OUT RO

**v0p2 arrangement ESPRO
**XRO G VSS VDD RO_OUT RO

**v0p51 arrangement ESPRO
**XRO G VSS NW VDD RO_OUT RO

**v0p51 arrangement PPG
XRO G VSS VDD RO_OUT RO


*      DC      init value peak value delay to pulse ramp time 1 ramp time 2 top width period
VG G 0 0 PULSE 0          PVDD        'settle+20p'            20p         20p         100n     200n

* note that node names below start with letter O

.TRAN   1p 15.0n

*.probe v(G) v(RO_OUT) i(VDD)  v(ET3)      V(ET4)    V(ET1)      V(ET2)   V(EN) V(HI) V(LO) V(RO_OUT)

*Rise and Fall delay
.measure tran tdlyfr1  TRIG V(RO_OUT) val=PVDD2 fall=1 TD='settle' TARG V(RO_OUT) val=PVDD2 rise=1
.measure tran tdlyrf1  TRIG V(RO_OUT) val=PVDD2 rise=1 TD='settle' TARG V(RO_OUT) val=PVDD2 fall=1

.measure delayfr  param='-1e12*(tdlyfr1/STAGES)'			  $[ps]
.measure delayrf  param='1e12*(tdlyrf1/STAGES)'		         	  $[ps]

* Delay (stage * 2 )
.measure tran delay2  TRIG V(RO_OUT) val=PVDD2 fall=1 TD='settle' TARG V(RO_OUT) val=PVDD2 fall=2

* Average stage delay
.measure stage_delay    param='1e12*(delay2/(2*STAGES))'                   $[ps]
.measure stage_freq     param='1000*(1/stage_delay)'                       $[GHz]

.measure tfall1 when V(RO_OUT)=PVDD2 fall=1 TD='settle'
.measure tfall2 when V(RO_OUT)=PVDD2 fall=2 TD='settle'
.measure tran idda_avg     AVG PAR('-1*I(VD)') from tfall1 to tfall2
.measure idda    param='1e6*idda_avg'                                      $[uA]

* Static current measured when circuit not switching
.measure tran iddq_avg     AVG PAR('-1*I(VD)') from 'settle' to 'settle+10p'
.measure iddq_stage     param='1e9*(iddq_avg/STAGES)'                      $[nA]


* Effective switching capacitance of circuit
* This captures capacitance of rising transition
* by monitoring charge provided by positive supply
.measure Ceff    param='1e3*(stage_delay*(idda_avg-iddq_avg)/PVDD2)'       $[fF]
.measure ACReff  param='1e-3*(PVDD/(2*(idda_avg-iddq_avg)))'               $[KOhm]

* Active and standby power
.measure pactive param='1e9*PVDD*(idda_avg-iddq_avg)'                      $[nW]
.measure pstdby  param='PVDD*iddq_stage'                                   $[nW]



*.param run_numx=0
*.param run_num=run_numx*1
*.measure run_num_out param='run_num'


*.param cg_s_d_n=1e-21
*.param cg_s_d_p=1e-21
*.param cg_b_np =1e-21

.END



