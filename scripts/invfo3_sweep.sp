
*.option brief=1
.option AUTOSTOP
.option ACCURATE
.option measdgt=5
.OPTIONS GMINDC=1e-18
.options INGOLD=1
.option OPFILE=1
.option post probe
.option NOMOD $ suppress model parameter info in .lis
.option LISLVL=1 $ suppress circuit name directory in .lis

.param PVDD=1.15
.temp =25

* Titan v0.02 TCAD w/ model build from Xiaoping
*.inc '/afs/apd.pok.ibm.com/ant/research/fet_models/titan/sb0.02/autogen/lib_230313/design_include.inc'

* Titan v0.03 FET model from Cronus PDK
*.inc ' /afs/apd/ant/research/prod/2HP/Cronus.01/SPICE/design_include.inc'

* Titan v0.1 FET model from Cronus PDK 
*.inc ' /afs/apd.pok.ibm.com/ant/research/test/2HP/V0.1/Spice/design_include.inc'

* Titan v0.11 FET model from Cronus PDK w/ Cgb added back in
*.inc ' /afs/apd.pok.ibm.com/ant/research/test/2HP/X0.11_240308/design_include.inc'


* Titan v0.11 FET model from Cronus PDK w/ Cgb added back in and edge Cdo+Cif added back in
*.inc ' /afs/apd.pok.ibm.com/ant/research/test/2HP/X0.11_240312/design_include.inc'

* modified 240312 model for pre-PDK estimate of v0.15 
*.inc ' /afs/apd.pok.ibm.com/u/rvega2/work4/PPG/spice/Titan/X0.11_240312/design_include.inc'

* early v0.15 model from Xiaoping
*.inc '/afs/apd/ant/research/test/2HP/v0.15.EarlyRelease.240429/HSPICE/design_include.inc'

* revised early v0.15 model from Xiaoping with additional Cedge fix (v0.15E2)
*.inc '/afs/apd/ant/research/test/2HP/v0.15.EarlyRelease.240509/HSPICE/design_include.inc'

* revised early v0.15 model from Henry (v0.15E3) includes v0.15E2 with additional cap penalty from dogbone, pc skirt, and rx upsize 4nm
*.inc '/afs/apd/ant/research/test/2HP/v0.15.EarlyRelease.240515/HSPICE/design_include.inc'

* revised early v0.15 model from Henry (v0.15E4) includes v0.15E2 with additional edge cap penalty from rx upsize 2nm
*.inc '/afs/apd/ant/research/test/2HP/X0.15.CapAdj.240620/Spice/design_include.inc'

* v0.15 final model release (should match v0.15E2)
*.inc '/afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.15/Spice/design_include.inc'

* v0.16 final model release 
*.inc '/afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.16/Spice/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.16/Spice/fixed_corner.lib TT

* v0.2 early spice model
*.inc '/afs/apd/ant/research/test/2HP/V0.2/Spice.241113_2/design_include.inc'

* v0.2 pre-release spice model with updated T sensitivity and FF, SS corners
*.inc '/afs/apd/ant/research/test/2HP/V0.2/Spice.241204_2/design_include.inc' 
*.lib /afs/apd/ant/research/test/2HP/V0.2/Spice.241204_2/fixed_corner.lib TT

* v0.2 rev2 model with new corners
*.inc '/afs/apd/ant/research/test/2HP/V0.2/Spice.241213/design_include.inc' 
*.lib /afs/apd/ant/research/test/2HP/V0.2/Spice.241213/fixed_corner.lib TT

* v0.2 final model release 
*.inc '/afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.2/Spice/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.2/Spice/fixed_corner.lib TT

* v0.21 early model release 
*.inc '/afs/apd.pok.ibm.com/ant/research/test/2HP/V0.21/Spice.250205/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/test/2HP/V0.21/Spice.250205/fixed_corner.lib TT

* v0.22 final model release 
*.inc '/afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.22/Spice/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.22/Spice/fixed_corner.lib TT

* pre-TC0Bv0.1 early model release 
*.inc '/afs/apd.pok.ibm.com/ant/research/test/2HPB/V0.2/Spice.250302/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/test/2HPB/V0.2/Spice.250302/fixed_corner.lib TT

* pre-TC0Bv0.1 early model release_v4 (7.5e18 well doping with 2/2 SC liner and updated self heating)
*.inc '/afs/apd.pok.ibm.com/ant/research/test/2HPB/V0.2/Spice.250331/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/test/2HPB/V0.2/Spice.250331/fixed_corner.lib TT

* 2HPB v0.2 final model release with Option 2+ structure
*.inc '/afs/apd.pok.ibm.com/ant/research/prod/2HPB/V0.2/Spice/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/prod/2HPB/V0.2/Spice/fixed_corner.lib TT


* v0.5 early model release 8, updated SS vs. T dependence
*.inc '/afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251205/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251205/fixed_corner.lib TT

* v0.5 early model release 10, fixed NCov runtime issue
*.inc '/afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251211/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.5/Spice.251211/fixed_corner.lib TT

* v0.51 early model release, with v0.5 patch material
*.inc '/afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.51/Spice/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.51/Spice/fixed_corner.lib TT

* v0.51 early model release, with v0.5 patch material across all Vt flavors
*.inc '/afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.51/Spice.260107/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/dev/2HP/V0.51/Spice.260107/fixed_corner.lib TT

* v0.51 prod model
*.inc '/afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.51/Spice/design_include.inc'
*.lib /afs/apd.pok.ibm.com/ant/research/prod/2HP/V0.51/Spice/fixed_corner.lib TT

* v0.51 prod model with rext tune added
*.inc '/afs/apd/ant/research/dev/2HP/V0.51/Spice-rext/design_include.inc'
*.lib /afs/apd/ant/research/dev/2HP/V0.51/Spice-rext/fixed_corner.lib TT

* v0.6SB model (same as v0.51 but with 29.26 aF/um Cov adder)
.inc '/afs/apd/ant/research/test/2HP/v0.53/Spice-260520-sandbox/design_include.inc'
.lib /afs/apd/ant/research/test/2HP/v0.53/Spice-260520-sandbox/fixed_corner.lib TT

* v0.6SB model with ELVT flavor added (NFET and PFET 60 mV Vtsat)
*.inc '/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/design_include.inc'
*.lib /afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/fixed_corner.lib TT

* v0.6SB model with ELVT, editable
*.inc '../FET_models/V0.53_Spice/Spice-260724-sandbox/design_include.inc'
*.lib ../FET_models/V0.53_Spice/Spice-260724-sandbox/fixed_corner.lib TT

* v0.6SB2 model (v0.51 w/ 29.26 aF/um uplift plus dRint = -14 Ohm-um, Rext = -25 Ohm-um)
*.inc '/afs/apd/ant/research/test/2HP/v0.53/Spice-260604-sandbox/design_include.inc'
*.lib /afs/apd/ant/research/test/2HP/v0.53/Spice-260604-sandbox/fixed_corner.lib TT

* v0.6SB3 model (v0.51 w/ 58 aF/um uplift plus dRint = -14 Ohm-um, Rext = -25 Ohm-um)
*.inc '/afs/apd/ant/research/test/2HP/v0.53/Spice-260616-sandbox/design_include.inc'
*.lib /afs/apd/ant/research/test/2HP/v0.53/Spice-260616-sandbox/fixed_corner.lib TT

.inc Titan_spf' 

*.param cov_tune = COVTUNE 

*.param rdext_tune = REXTTUNE $ in 0hm-um
*.param rsext_tune = REXTTUNE $ in 0hm-um


*.param shmod=0

.param PVSS  = 0
.param PVDD2 = 'PVDD/2'

.param PVDD001 = 'PVDD*0.001'
.param PVDD005 = 'PVDD*0.005'
.param PVDD01 = 'PVDD*0.01'
.param PVDD05 = 'PVDD*0.05'
.param PVDD10 = 'PVDD*0.1'
.param PVDD15 = 'PVDD*0.15'
.param PVDD20 = 'PVDD*0.2'
.param PVDD25 = 'PVDD*0.25'
.param PVDD30 = 'PVDD*0.3'
.param PVDD35 = 'PVDD*0.35'
.param PVDD40 = 'PVDD*0.4'
.param PVDD45 = 'PVDD*0.45'
.param PVDD50 = 'PVDD*0.5'
.param PVDD55 = 'PVDD*0.55'
.param PVDD60 = 'PVDD*0.6'
.param PVDD65 = 'PVDD*0.65'
.param PVDD70 = 'PVDD*0.7'
.param PVDD75 = 'PVDD*0.75'
.param PVDD80 = 'PVDD*0.8'
.param PVDD85 = 'PVDD*0.85'
.param PVDD90 = 'PVDD*0.9'
.param PVDD95 = 'PVDD*0.95'
.param PVDD99 = 'PVDD*0.99'
.param PVDD995 = 'PVDD*0.995'
.param PVDD999 = 'PVDD*0.999'

.op $ combined with .option OPFILE=1 to suppress op info in .lis and output to a separate file
.TRAN   1p  10n

*      DC      init value peak value delay to pulse ramp time 1 ramp time 2 top width period
VG G 0 0 PULSE PVDD       0          10p            20p         20p         500n     1000n
VS SS 0 PVSS
VD DD 0 PVDD

*     VDD A VSS Z 
*XINV1  16 G  29 01 Titan_RO
*XINV2  17 01 30 02 Titan_RO
*XINV3  18 02 31 03 Titan_RO
*XINV4  19 03 32 04 Titan_RO
*XINV5  20 04 33 05 Titan_RO
*XINV6  21 05 34 06 Titan_RO
*XINV7  22 06 35 07 Titan_RO
*R7	07	08	1A
*XINV8  23 08 36 09 Titan_RO
*R8	09	10	1A
*XINV9  24 10 37 11 Titan_RO
*XINV10 25 11 38 12 Titan_RO
*XINV11 26 12 39 13 Titan_RO
*XINV12 27 13 40 14 Titan_RO
*XINV13 28 14 41 15 Titan_RO

*	VSS	VDD	A	Z	
XINV1	29	16	G	01	Titan_RO
XINV2	30	17	01	02	Titan_RO
XINV3	31	18	02	03	Titan_RO
XINV4	32	19	03	04	Titan_RO
XINV5	33	20	04	05	Titan_RO
XINV6	34	21	05	06	Titan_RO
XINV7	35	22	06	07	Titan_RO
R7		07	08	1A	
XINV8	36	23	08	09	Titan_RO
R8		09	10	1A	
XINV9	37	24	10	11	Titan_RO
XINV10	38	25	11	12	Titan_RO
XINV11	39	26	12	13	Titan_RO
XINV12	40	27	13	14	Titan_RO
XINV13	41	28	14	15	Titan_RO


.param Rpower=1A

R10	DD	16	Rpower
R20	DD	17	Rpower
R30	DD	18	Rpower
R40	DD	19	Rpower
R50	DD	20	Rpower
R60	DD	21	Rpower
R70	DD	22	Rpower
R80	DD	23	Rpower
R90	DD	24	Rpower
R100	DD	25	Rpower
R110	DD	26	Rpower
R120	DD	27	Rpower
R130	DD	28	Rpower

R1001	SS	29	Rpower
R2001	SS	30	Rpower
R3001	SS	31	Rpower
R4001	SS	32	Rpower
R5001	SS	33	Rpower
R6001	SS	34	Rpower
R7001	SS	35	Rpower
R8001	SS	36	Rpower
R9001	SS	37	Rpower
R10001	SS	38	Rpower
R11001	SS	39	Rpower
R12001	SS	40	Rpower
R13001	SS	41	Rpower

*.param Cload=0.1F
*.measure Cw  param = 'Cload'

*C1 01 0 Cload
*C2 02 0 Cload
*C3 03 0 Cload
*C4 04 0 Cload
*C5 05 0 Cload
*C6 06 0 Cload
*C7 07 0 Cload
*C8 09 0 Cload
*C9 11 0 Cload
*C10 12 0 Cload
*C11 13 0 Cload 
*C12 14 0 Cload
*C13 15 0 Cload

*.measure tran tdlyrr1  TRIG V(07) val=PVDD2 rise=1 TARG V(09) val=PVDD2 rise=1
*.measure tran tdlyfr1  TRIG V(08) val=PVDD2 fall=1 TD=500n TARG V(09) val=PVDD2 rise=1
*.measure tran tdlyrf1  TRIG V(07) val=PVDD2 rise=1 TD=500n TARG V(08) val=PVDD2 fall=1
.measure tran tdlyrr1  TRIG V(07) val=PVDD2 rise=1 TARG V(11) val=PVDD2 rise=1
.measure tran tdlyfr1  TRIG V(09) val=PVDD2 fall=1 TD=500n TARG V(11) val=PVDD2 rise=1
.measure tran tdlyrf1  TRIG V(07) val=PVDD2 rise=1 TD=500n TARG V(09) val=PVDD2 fall=1

.measure tfall21 when V(02)=PVDD2 fall=1
.measure trise31 when V(03)=PVDD2 rise=1
.measure tfall41 when V(04)=PVDD2 fall=1
.measure trise51 when V(05)=PVDD2 rise=1
.measure tfall61 when V(06)=PVDD2 fall=1
.measure trise71 when V(07)=PVDD2 rise=1
*.measure tfall81 when V(08)=PVDD2 fall=1
*.measure trise91 when V(09)=PVDD2 rise=1
.measure tfall81 when V(09)=PVDD2 fall=1
.measure trise91 when V(11)=PVDD2 rise=1
.measure tfall101 when V(12)=PVDD2 fall=1
.measure trise111 when V(13)=PVDD2 rise=1
.measure tfall121 when V(14)=PVDD2 fall=1
.measure trise131 when V(15)=PVDD2 rise=1

.measure trise501 when V(05)=PVDD01 rise=1
.measure trise550 when V(05)=PVDD50 rise=1
.measure tfall601 when V(06)=PVDD01 fall=1
.measure tfall610 when V(06)=PVDD10 fall=1
.measure tfall650 when V(06)=PVDD50 fall=1
.measure tfall699 when V(06)=PVDD99 fall=1

.measure trise7005 when V(07)=PVDD005 rise=1
.measure trise701 when V(07)=PVDD01 rise=1
.measure trise705 when V(07)=PVDD05 rise=1
.measure trise710 when V(07)=PVDD10 rise=1
.measure trise715 when V(07)=PVDD15 rise=1
.measure trise720 when V(07)=PVDD20 rise=1
.measure trise725 when V(07)=PVDD25 rise=1
.measure trise730 when V(07)=PVDD30 rise=1
.measure trise735 when V(07)=PVDD35 rise=1
.measure trise740 when V(07)=PVDD40 rise=1
.measure trise745 when V(07)=PVDD45 rise=1
.measure trise750 when V(07)=PVDD50 rise=1
.measure trise755 when V(07)=PVDD55 rise=1
.measure trise760 when V(07)=PVDD60 rise=1
.measure trise765 when V(07)=PVDD65 rise=1
.measure trise770 when V(07)=PVDD70 rise=1
.measure trise775 when V(07)=PVDD75 rise=1
.measure trise780 when V(07)=PVDD80 rise=1
.measure trise785 when V(07)=PVDD85 rise=1
.measure trise790 when V(07)=PVDD90 rise=1
.measure trise795 when V(07)=PVDD95 rise=1
.measure trise799 when V(07)=PVDD99 rise=1
.measure trise7995 when V(07)=PVDD995 rise=1

.measure tfall699 when V(06)=PVDD99 fall=1
.measure trise999 when V(11)=PVDD99 rise=1

.measure tfall8005 when V(09)=PVDD005 fall=1
.measure tfall801 when V(09)=PVDD01 fall=1
.measure tfall805 when V(09)=PVDD05 fall=1
.measure tfall810 when V(09)=PVDD10 fall=1
.measure tfall815 when V(09)=PVDD15 fall=1
.measure tfall820 when V(09)=PVDD20 fall=1
.measure tfall825 when V(09)=PVDD25 fall=1
.measure tfall830 when V(09)=PVDD30 fall=1
.measure tfall835 when V(09)=PVDD35 fall=1
.measure tfall840 when V(09)=PVDD40 fall=1
.measure tfall845 when V(09)=PVDD45 fall=1
.measure tfall850 when V(09)=PVDD50 fall=1
.measure tfall855 when V(09)=PVDD55 fall=1
.measure tfall860 when V(09)=PVDD60 fall=1
.measure tfall865 when V(09)=PVDD65 fall=1
.measure tfall870 when V(09)=PVDD70 fall=1
.measure tfall875 when V(09)=PVDD75 fall=1
.measure tfall880 when V(09)=PVDD80 fall=1
.measure tfall885 when V(09)=PVDD85 fall=1
.measure tfall890 when V(09)=PVDD90 fall=1
.measure tfall895 when V(09)=PVDD95 fall=1
.measure tfall899 when V(09)=PVDD99 fall=1
.measure tfall8995 when V(09)=PVDD995 fall=1

.measure tran idda10     	   AVG PAR('-1*I(VD)') from trise705 to trise715
.measure tran idda15     	   AVG PAR('-1*I(VD)') from trise710 to trise720
.measure tran idda20     	   AVG PAR('-1*I(VD)') from trise715 to trise725
.measure tran idda25     	   AVG PAR('-1*I(VD)') from trise720 to trise730
.measure tran idda30     	   AVG PAR('-1*I(VD)') from trise725 to trise735
.measure tran idda35     	   AVG PAR('-1*I(VD)') from trise730 to trise740
.measure tran idda40     	   AVG PAR('-1*I(VD)') from trise735 to trise745
.measure tran idda45     	   AVG PAR('-1*I(VD)') from trise740 to trise750
.measure tran idda50     	   AVG PAR('-1*I(VD)') from trise745 to trise755
.measure tran idda55     	   AVG PAR('-1*I(VD)') from trise750 to trise760
.measure tran idda60     	   AVG PAR('-1*I(VD)') from trise755 to trise765
.measure tran idda65     	   AVG PAR('-1*I(VD)') from trise760 to trise770
.measure tran idda70     	   AVG PAR('-1*I(VD)') from trise765 to trise775
.measure tran idda75     	   AVG PAR('-1*I(VD)') from trise770 to trise780
.measure tran idda80     	   AVG PAR('-1*I(VD)') from trise775 to trise785
.measure tran idda85     	   AVG PAR('-1*I(VD)') from trise780 to trise790
.measure tran idda90     	   AVG PAR('-1*I(VD)') from trise785 to trise795

.measure tran iddf10     	   AVG PAR('-1*I(VD)') from tfall805 to tfall815
.measure tran iddf15     	   AVG PAR('-1*I(VD)') from tfall810 to tfall820
.measure tran iddf20     	   AVG PAR('-1*I(VD)') from tfall815 to tfall825
.measure tran iddf25     	   AVG PAR('-1*I(VD)') from tfall820 to tfall830
.measure tran iddf30     	   AVG PAR('-1*I(VD)') from tfall825 to tfall835
.measure tran iddf35     	   AVG PAR('-1*I(VD)') from tfall830 to tfall840
.measure tran iddf40     	   AVG PAR('-1*I(VD)') from tfall835 to tfall845
.measure tran iddf45     	   AVG PAR('-1*I(VD)') from tfall840 to tfall850
.measure tran iddf50     	   AVG PAR('-1*I(VD)') from tfall845 to tfall855
.measure tran iddf55     	   AVG PAR('-1*I(VD)') from tfall850 to tfall860
.measure tran iddf60     	   AVG PAR('-1*I(VD)') from tfall855 to tfall865
.measure tran iddf65     	   AVG PAR('-1*I(VD)') from tfall860 to tfall870
.measure tran iddf70     	   AVG PAR('-1*I(VD)') from tfall865 to tfall875
.measure tran iddf75     	   AVG PAR('-1*I(VD)') from tfall870 to tfall880
.measure tran iddf80     	   AVG PAR('-1*I(VD)') from tfall875 to tfall885
.measure tran iddf85     	   AVG PAR('-1*I(VD)') from tfall880 to tfall890
.measure tran iddf90     	   AVG PAR('-1*I(VD)') from tfall885 to tfall895

.measure tran R7idda10     	   AVG PAR('1*I(R7)') from trise705 to trise715
.measure tran R7idda15     	   AVG PAR('1*I(R7)') from trise710 to trise720
.measure tran R7idda20     	   AVG PAR('1*I(R7)') from trise715 to trise725
.measure tran R7idda25     	   AVG PAR('1*I(R7)') from trise720 to trise730
.measure tran R7idda30     	   AVG PAR('1*I(R7)') from trise725 to trise735
.measure tran R7idda35     	   AVG PAR('1*I(R7)') from trise730 to trise740
.measure tran R7idda40     	   AVG PAR('1*I(R7)') from trise735 to trise745
.measure tran R7idda45     	   AVG PAR('1*I(R7)') from trise740 to trise750
.measure tran R7idda50     	   AVG PAR('1*I(R7)') from trise745 to trise755
.measure tran R7idda55     	   AVG PAR('1*I(R7)') from trise750 to trise760
.measure tran R7idda60     	   AVG PAR('1*I(R7)') from trise755 to trise765
.measure tran R7idda65     	   AVG PAR('1*I(R7)') from trise760 to trise770
.measure tran R7idda70     	   AVG PAR('1*I(R7)') from trise765 to trise775
.measure tran R7idda75     	   AVG PAR('1*I(R7)') from trise770 to trise780
.measure tran R7idda80     	   AVG PAR('1*I(R7)') from trise775 to trise785
.measure tran R7idda85     	   AVG PAR('1*I(R7)') from trise780 to trise790
.measure tran R7idda90     	   AVG PAR('1*I(R7)') from trise785 to trise795

.measure tran R8idda10     	   AVG PAR('1*I(R8)') from tfall805 to tfall815
.measure tran R8idda15     	   AVG PAR('1*I(R8)') from tfall810 to tfall820
.measure tran R8idda20     	   AVG PAR('1*I(R8)') from tfall815 to tfall825
.measure tran R8idda25     	   AVG PAR('1*I(R8)') from tfall820 to tfall830
.measure tran R8idda30     	   AVG PAR('1*I(R8)') from tfall825 to tfall835
.measure tran R8idda35     	   AVG PAR('1*I(R8)') from tfall830 to tfall840
.measure tran R8idda40     	   AVG PAR('1*I(R8)') from tfall835 to tfall845
.measure tran R8idda45     	   AVG PAR('1*I(R8)') from tfall840 to tfall850
.measure tran R8idda50     	   AVG PAR('1*I(R8)') from tfall845 to tfall855
.measure tran R8idda55     	   AVG PAR('1*I(R8)') from tfall850 to tfall860
.measure tran R8idda60     	   AVG PAR('1*I(R8)') from tfall855 to tfall865
.measure tran R8idda65     	   AVG PAR('1*I(R8)') from tfall860 to tfall870
.measure tran R8idda70     	   AVG PAR('1*I(R8)') from tfall865 to tfall875
.measure tran R8idda75     	   AVG PAR('1*I(R8)') from tfall870 to tfall880
.measure tran R8idda80     	   AVG PAR('1*I(R8)') from tfall875 to tfall885
.measure tran R8idda85     	   AVG PAR('1*I(R8)') from tfall880 to tfall890
.measure tran R8idda90     	   AVG PAR('1*I(R8)') from tfall885 to tfall895

.measure tran R70idda05     	   AVG PAR('1*I(R70)') from trise701 to trise710
.measure tran R70idda10     	   AVG PAR('1*I(R70)') from trise705 to trise715
.measure tran R70idda15     	   AVG PAR('1*I(R70)') from trise710 to trise720
.measure tran R70idda20     	   AVG PAR('1*I(R70)') from trise715 to trise725
.measure tran R70idda25     	   AVG PAR('1*I(R70)') from trise720 to trise730
.measure tran R70idda30     	   AVG PAR('1*I(R70)') from trise725 to trise735
.measure tran R70idda35     	   AVG PAR('1*I(R70)') from trise730 to trise740
.measure tran R70idda40     	   AVG PAR('1*I(R70)') from trise735 to trise745
.measure tran R70idda45     	   AVG PAR('1*I(R70)') from trise740 to trise750
.measure tran R70idda50     	   AVG PAR('1*I(R70)') from trise745 to trise755
.measure tran R70idda55     	   AVG PAR('1*I(R70)') from trise750 to trise760
.measure tran R70idda60     	   AVG PAR('1*I(R70)') from trise755 to trise765
.measure tran R70idda65     	   AVG PAR('1*I(R70)') from trise760 to trise770
.measure tran R70idda70     	   AVG PAR('1*I(R70)') from trise765 to trise775
.measure tran R70idda75     	   AVG PAR('1*I(R70)') from trise770 to trise780
.measure tran R70idda80     	   AVG PAR('1*I(R70)') from trise775 to trise785
.measure tran R70idda85     	   AVG PAR('1*I(R70)') from trise780 to trise790
.measure tran R70idda90     	   AVG PAR('1*I(R70)') from trise785 to trise795
.measure tran R70idda95     	   AVG PAR('1*I(R70)') from trise790 to trise799

.measure tran R80idda05     	   AVG PAR('1*I(R80)') from tfall801 to tfall810
.measure tran R80idda10     	   AVG PAR('1*I(R80)') from tfall805 to tfall815
.measure tran R80idda15     	   AVG PAR('1*I(R80)') from tfall810 to tfall820
.measure tran R80idda20     	   AVG PAR('1*I(R80)') from tfall815 to tfall825
.measure tran R80idda25     	   AVG PAR('1*I(R80)') from tfall820 to tfall830
.measure tran R80idda30     	   AVG PAR('1*I(R80)') from tfall825 to tfall835
.measure tran R80idda35     	   AVG PAR('1*I(R80)') from tfall830 to tfall840
.measure tran R80idda40     	   AVG PAR('1*I(R80)') from tfall835 to tfall845
.measure tran R80idda45     	   AVG PAR('1*I(R80)') from tfall840 to tfall850
.measure tran R80idda50     	   AVG PAR('1*I(R80)') from tfall845 to tfall855
.measure tran R80idda55     	   AVG PAR('1*I(R80)') from tfall850 to tfall860
.measure tran R80idda60     	   AVG PAR('1*I(R80)') from tfall855 to tfall865
.measure tran R80idda65     	   AVG PAR('1*I(R80)') from tfall860 to tfall870
.measure tran R80idda70     	   AVG PAR('1*I(R80)') from tfall865 to tfall875
.measure tran R80idda75     	   AVG PAR('1*I(R80)') from tfall870 to tfall880
.measure tran R80idda80     	   AVG PAR('1*I(R80)') from tfall875 to tfall885
.measure tran R80idda85     	   AVG PAR('1*I(R80)') from tfall880 to tfall890
.measure tran R80idda90     	   AVG PAR('1*I(R80)') from tfall885 to tfall895
.measure tran R80idda95     	   AVG PAR('1*I(R80)') from tfall890 to tfall899

.measure tran R7001idda05     	   AVG PAR('1*I(R7001)') from trise701 to trise710
.measure tran R7001idda10     	   AVG PAR('1*I(R7001)') from trise705 to trise715
.measure tran R7001idda15     	   AVG PAR('1*I(R7001)') from trise710 to trise720
.measure tran R7001idda20     	   AVG PAR('1*I(R7001)') from trise715 to trise725
.measure tran R7001idda25     	   AVG PAR('1*I(R7001)') from trise720 to trise730
.measure tran R7001idda30     	   AVG PAR('1*I(R7001)') from trise725 to trise735
.measure tran R7001idda35     	   AVG PAR('1*I(R7001)') from trise730 to trise740
.measure tran R7001idda40     	   AVG PAR('1*I(R7001)') from trise735 to trise745
.measure tran R7001idda45     	   AVG PAR('1*I(R7001)') from trise740 to trise750
.measure tran R7001idda50     	   AVG PAR('1*I(R7001)') from trise745 to trise755
.measure tran R7001idda55     	   AVG PAR('1*I(R7001)') from trise750 to trise760
.measure tran R7001idda60     	   AVG PAR('1*I(R7001)') from trise755 to trise765
.measure tran R7001idda65     	   AVG PAR('1*I(R7001)') from trise760 to trise770
.measure tran R7001idda70     	   AVG PAR('1*I(R7001)') from trise765 to trise775
.measure tran R7001idda75     	   AVG PAR('1*I(R7001)') from trise770 to trise780
.measure tran R7001idda80     	   AVG PAR('1*I(R7001)') from trise775 to trise785
.measure tran R7001idda85     	   AVG PAR('1*I(R7001)') from trise780 to trise790
.measure tran R7001idda90     	   AVG PAR('1*I(R7001)') from trise785 to trise795
.measure tran R7001idda95     	   AVG PAR('1*I(R7001)') from trise790 to trise799

.measure tran R8001idda05     	   AVG PAR('1*I(R8001)') from tfall801 to tfall810
.measure tran R8001idda10     	   AVG PAR('1*I(R8001)') from tfall805 to tfall815
.measure tran R8001idda15     	   AVG PAR('1*I(R8001)') from tfall810 to tfall820
.measure tran R8001idda20     	   AVG PAR('1*I(R8001)') from tfall815 to tfall825
.measure tran R8001idda25     	   AVG PAR('1*I(R8001)') from tfall820 to tfall830
.measure tran R8001idda30     	   AVG PAR('1*I(R8001)') from tfall825 to tfall835
.measure tran R8001idda35     	   AVG PAR('1*I(R8001)') from tfall830 to tfall840
.measure tran R8001idda40     	   AVG PAR('1*I(R8001)') from tfall835 to tfall845
.measure tran R8001idda45     	   AVG PAR('1*I(R8001)') from tfall840 to tfall850
.measure tran R8001idda50     	   AVG PAR('1*I(R8001)') from tfall845 to tfall855
.measure tran R8001idda55     	   AVG PAR('1*I(R8001)') from tfall850 to tfall860
.measure tran R8001idda60     	   AVG PAR('1*I(R8001)') from tfall855 to tfall865
.measure tran R8001idda65     	   AVG PAR('1*I(R8001)') from tfall860 to tfall870
.measure tran R8001idda70     	   AVG PAR('1*I(R8001)') from tfall865 to tfall875
.measure tran R8001idda75     	   AVG PAR('1*I(R8001)') from tfall870 to tfall880
.measure tran R8001idda80     	   AVG PAR('1*I(R8001)') from tfall875 to tfall885
.measure tran R8001idda85     	   AVG PAR('1*I(R8001)') from tfall880 to tfall890
.measure tran R8001idda90     	   AVG PAR('1*I(R8001)') from tfall885 to tfall895
.measure tran R8001idda95     	   AVG PAR('1*I(R8001)') from tfall890 to tfall899


.measure tran idda7     	   AVG PAR('1*I(R7)') from trise701 to trise799
.measure tran idda8     	   AVG PAR('1*I(R8)') from tfall899 to tfall801

.measure tran vmax  MAX V(06) from 0 to tfall650
.measure tmax when V(06)=vmax from 0 to tfall650

.measure tran vmin  MIN V(06) from tfall650 to trise799
.measure tmin when V(06)=vmax from tfall650 to trise799

.measure tran ieff70a     	   AVG PAR('1*I(R70)') from tmax to trise750
.measure reff70a param='PVDD2/ieff70a'

.measure tran idda7001     	   AVG PAR('1*I(R7001)') from trise701 to trise799
.measure tran idda7001a     	   AVG PAR('1*I(R7001)') from tfall899 to tfall801
.measure tran idda8001     	   AVG PAR('1*I(R8001)') from tfall899 to tfall801
.measure tran idda70     	   AVG PAR('1*I(R70)') from trise701 to trise799
.measure tran idda70a     	   AVG PAR('1*I(R70)') from tfall899 to tfall801
.measure tran idda80     	   AVG PAR('1*I(R80)') from tfall899 to tfall801
.measure tran iddq70     	   FIND PAR('1*I(R70)') AT=0ps
.measure tran iddq80			    FIND PAR('1*I(R80)') AT=0ps

.measure tran Q70testa     	   INTEG PAR('1*I(R70)') from trise720 to trise740
.measure tran Q70     	    INTEG PAR('1*I(R70)') from tfall699 to tfall801
.measure tran Q80    	   INTEG PAR('1*I(R80)') from trise701 to trise999
.measure tran Q8001    	   INTEG PAR('1*I(R8001)') from trise701 to trise999
.measure tran Qiddq_avg		      INTEG PAR('-(1/6)*I(VD)') from 2p to 8p
.measure Qiddq_avg_stg param = 'Qiddq_avg/6e-12'

.measure idda2 param='idda7001+idda70'
.measure idda3 param='0-(idda8001+idda80)'
.measure Qrailb param = '0.5*(Q70-Q8001)'
.measure Qrailc param = '(Q70+Q80)'


.measure iddarail	param='0.5*(idda70-idda8001)'
.measure idda	param='0.5*(idda2+idda3)'
.measure iddq	param='0.5*(iddq70+iddq80)'

*.measure tran iddaorig     	   AVG PAR('-1*I(VD)') from trise71 to trise91
.measure tran iddq_avg     AVG PAR('-1*I(VD)') from 2p to 8p
*.measure tran iddqorig         FIND PAR('-1*I(VD)') AT=0ps

*.measure tran inwell       FIND PAR('-1*I(VD2)') AT=0ps
*.measure tran inwell_avg   AVG PAR('-1*I(VD2)') from 2p to 8p
.measure power_supply param = 'PVDD'
.measure stage_delay  param = 'tdlyrr1/2*1e12'
.measure acreff       param = '(power_supply)*0.5/(idda-iddq)'
.measure acceff       param = '1e-12*stage_delay/acreff'

.measure acreffrail       param = '(power_supply)*0.5/(iddarail-iddq)'
.measure acceffrail       param = '1e-12*stage_delay/acreffrail' 

.measure iddarail_Q			  param = '(Qrailb/(stage_delay*1e-12))-Qiddq_avg_stg'
.measure acceffrail_Q			  param = '0.5*Qrailb/PVDD'
.measure acreffrail_Q     param = '1e-12*stage_delay/acceffrail_Q'

.measure iddarail_Qcorr			  param = '(Qrailc/(stage_delay*1e-12))-Qiddq_avg_stg'
.measure acceffrail_Qcorr			  param = 'Qrailc/PVDD'
*.measure Qraild param = 'iddarail_Qcorr*stage_delay*1e-12'
*.measure acceffrail_Qcorr			  param = 'Qraild/PVDD'
.measure acreffrail_Qcorr     param = '1e-12*stage_delay/acceffrail_Qcorr'

*.measure acrefforig       param = '(power_supply)*0.5/(iddaorig-iddqorig)'
*.measure accefforig       param = '1e-12*stage_delay/acrefforig'

.print I(R7001) I(R70) V(07) V(06)

.END
