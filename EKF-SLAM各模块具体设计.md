# EKF-SLAM各模块具体设计



## 预测流程

NL: NonLinear, 非线性模块



PS发出PRD信号

RSA读出NL所需数据

RSA向NL发出PRD，同时传输数据

NL计算

NL向RSA发出PRD，同时传输数据

RSA将数据写入

RSA开始矩阵运算

完成



## 数据端口

### 外部

输入

* stage
* vlr
* alpha
* r_k
* phi_k
* lk_num
* 

输出

* S矩阵（串行）



### RSA--NonLinear

RSA输出

* start_prd, start_new, start_upd
* x_i, y_i, theta_i
* lk_x,lk_y

NonLinear输出

* done_prd, done_new, done_upd
* 5个result



## 数据流

读BRAM -> BRAM_dout_map -> PEin_MUX -> PE行列输入 -> PE行输出 -> PEout_deMUX -> BRAM_din_map -> 写BRAM

### 读BRAM

产生addr_new, en_new, we_new，每个时钟进行移位，从而实现每个BANK的读时序

控制量：

* TBa, TBb, CBa, CBb
  * addr_new
  * en_new
  * we_new
* 移位后产生对应的addr, en, we

分为三种模式：

* POS: __new -> BANK0 ---> BANK3
* NEG: __new -> BANK3 ---> BANK0
* NEW: 根据地标点进行寻址
  * l_k[0] == 0: __new -> BANK0 -> BANK1 
  * l_k[0] == 1: __new -> BANK2 -> BANK3

### BRAM_dout_map

将BRAM的4条BANK映射到PE输入的4条BANK

控制量：

* TB_douta_sel[2:0]
* TB_doutb_sel[2:0]
* CB_douta_sel[3:0]

#### TB_douta_map

```
/*
  TB_douta_sel[2]
    1: M
    0: A
  TB_douta_sel[1:0]
    00: DIR_IDLE
    01: POS
    10: NEG
    11: X
*/
```

#### TB_doutb_map

```
/*
  TB_doutb_sel[2]
    1: B_cache
    0: B
  TB_doutb_sel[1:0]
          B              B_cache
    00: DIR_IDLE      B_cache_IDLE
    01: POS           B_cache_trnsfer    搬运至B_cache
    10: NEG           B_cache_transpose  转置后存入B_cache
    11: NEW           B_cache_inv        求逆后存入B_cache
*/
```

#### CB_douta_map

```
/*
  CB_douta_sel[3:2]
    11: M
    10: B
    01: A
    00: CBa -> TBa
  CB_douta_sel[1:0]
    00: DIR_IDLE
    01: POS
    10: NEG
    11: NEW
*/
```

### PE_in_MUX

选择PE行列输入的数据来源

数据来源：

* CB 协方差矩阵
* TB 中间变量矩阵
* cache 暂存数据

控制量：

* A_in_sel, B_in_sel, M_in_sel, C_out_sel: 选择数据输入

```
/*
  B_in_sel
    00: TB
    01: cache
    10: CB
    11: X
*/
```

* A_in_en, B_in_en, M_in_en, C_out_en: 使能信号



### PE阵列输入：

* PE_mode: PE计算模式
* A_data, B_data, M_data: 
* new_cal_en: 计算使能
* new_cal_done: 计算终止信号
* M_adder_mode: 加法模式
  * 00：不执行加法
  * 01：M + C
  * 10：C - M
  * 11：M - C



### PEout_deMUX

数据解复用

```
C_regdeMUX_sel
  00: TB
  01: cache
  10: CB
  11: x
```



### BRAM_din_map

#### TB_dina_map

```
/*
  TB_dina_sel[2]
    0: TBa_CBa        从CB读取的数据
    1: TBa_non_linear 非线性单元输入
  TB_dina_sel[1:0]
    00: DIR_IDLE
    01: POS
    10: NEG
    11: NEW
*/
```

#### TB_dinb_map

```
/*
  数据均来自PE阵列输出
  TB_dinb_sel[1:0]
    00: DIR_IDLE
    01: POS
    10: NEG
    11: NEW
*/
```

#### CB_dinb_map

```
/*
  数据均来自PE阵列输出
  CB_dinb_sel[1:0]
    00: DIR_IDLE
    01: POS
    10: NEG
    11: NEW
*/
```



### 时序

| T        |           | set                                         |
| -------- | --------- | ------------------------------------------- |
| 0        | stage     | CAL_mode, TB_mode, CB_mode，addr_base       |
| 1        | addr_new  | addr_shift_dir                              |
| 2        | addr[0]   | CB_douta_sel_new, CB_douta_sel_dir          |
| 3        | CB_dout   | A_in_sel_new, A_in_sel_dir,                 |
| 4        | A_CB_dout | cal_en_new, cal_done_new, A_in_en           |
| 5        | A_data    | PE_mode                                     |
| 6        |           |                                             |
| 7        |           |                                             |
| 8        |           | M_in_sel_new, M_in_sel_dir                  |
| 9        | M_data    | C_in_sel_new, C_in_sel_dir                  |
| 10(WR 0) | C_data    | CB_dinb_sel_new, CB_dinb_sel_dir, addr_base |
| 11(WR 1) | C_CB_dinb | addr_new, addr_shift_dir                    |
| 12(WR 2) | CB_dinb   | addr[0]                                     |
|          |           |                                             |



## 状态机

* IDLE
* PRD 预测
  * non_linear
  * PRD_1
  * PRD_2
  * PRD_3
* ASSOC 数据关联
* NEW 新地标初始化
* UPD 更新



## RSA

ip_repo：DigitalLAB\ip_repo

源文件：sources_dev



### PE阵列

大小：2个4*4阵列

特点：

* 可配置数据在PE阵列内的流动方向
* 可对单个PE单元使能
* 

调度：

* 矩阵运算：1个4*4 PE阵列，根据矩阵维度使能
* 协方差矩阵更新O(n^2) 2个4*4PE阵列
* 数据关联(未作)：可以利用H矩阵稀疏性简化运算，各子矩阵运算可并行，尝试将4\*4的PE阵列拆分为4个2\*2或2个2\*4

### PE单元



## 非线性