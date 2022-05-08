# PE模块开发

## RSA设计

### PE_port

#### 输入

三态门

#### 输出

三态门（完成）

何时开始输出？

### PE_config

SA_start: 未自动化

3*3 

以cal_en拉高为起点

* 计算：N+1个时钟，得到输出
* 输出：以求和完成为起点，2N-1个时钟得到输出

所以，每一块为3*3是很合理的，上一批在输出时，这一批在计算



取消config

* westin->eastout
* northin->southout
* din->dout: 输出横向传递
* n_cal_en->cal_en, cal_done: 第一行横向传递，对每一列，纵向传递



特殊情况

* (1,1)：cal_en，cal_done

## 开发流程

使用

* 画逻辑框图
* 画波形图(visio)，根据波形图分析逻辑的正确性
* 参照波形图，编写verilog代码
* modelsim仿真，比照波形



## syncFIFO

参考正点原子逻辑设计参考手册

## VSCode编写Verilog

脚本，插件，https://blog.csdn.net/larpland/article/details/101349586

注意需安装chardet

* pip换源
* anaconda虚拟环境，需要在anaconda prompt内运行python文件



## Modelsim

* 安装，破解
* 先创建Library -- work
* 创建Project
  * 引用文件。这样修改文件可同步到modelsim中
  * modelsim文件夹中只是引用，移出project不会删除文件
* 一些操作
  * restart：可以重新开始
  * run：在现有波形后再仿真一轮
  * 修改程序后，编译相应程序，然后在仿真页面restart，选择reload，不必重新打开
* 快捷键：

## 资源

* 布线资源 or 触发器资源？ (cal_en的处理)
* 由于输出可能接到模块，故将输出的坐标与PE坐标绑定，输入与来源的PE坐标绑定
* 

220209

* cal_en cal_done传递路线与
* 未完成顶层模块的testbench
* 未仿真fifo，config

220210

* fifo需要分west和north
* 增加fifo读取的接口
* 带参数串转并：寄存器型变量reg驱动输入
* 直接输出：![image-20220210193635858](C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220210193635858.png)
* 已经设置了fifo了，只需通过使能信号即可控制是否读取数据。输入信号可以接到一起
* 左移！从1号wr_en到2号wr_en

220212

* 相对路径问题[Verilog include 使用相对路径 - 米兰de小铁匠 - 博客园 (cnblogs.com)](https://www.cnblogs.com/undermyownmoon/p/10442780.html)
  * 需要在与modelsim仿真工程work文件夹同级创建一个data文件夹，存放数据文件

```verilog
fd = $fopen("data/DATA.HEX");
```



* 计算正确，din过早出现，怀疑是连线问题

220213

赋0 仍出现不定态

<img src="C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220213173815129.png" alt="image-20220213173815129" style="zoom:50%;" />

![image-20220213173750854](C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220213173750854.png)

而(X,Y)的PE没有出现问题

发现是(1,Y)的din_val没有接到din_val_gnd

![image-20220213183305472](C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220213183305472.png)

![image-20220213183247492](C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220213183247492.png)

modelsim保存仿真设置和仿真波形

[modelsim中仿真波形设置的保存_坚持-CSDN博客_questasim保存波形](https://blog.csdn.net/wordwarwordwar/article/details/55254441)



220301

* 取消原config
* westin[1].rd_en是wesin[X].wr_en的1级缓存（总成立）
* cal_en[1]是westin[1].wr_en的一级缓存（总成立）
* cal_done[1]由{cal_en[1]，cal_en[1]_r}=2’b01生成
* out_rd_en：dout_val[1]使能计数两次，开始输出，重新计数
* 最后一行的n_cal_en恰好可以作为northin_fifo的写使能信号！
  * 注意：需要用逻辑门/三态门实现数据传输
* fifo 取消n_rd_en



220303

* 连续，差一个周期T（输出极限情况下）
  * westin.rd_en可以再抢一个T
* fifo透传模式
  * 当{wr_en,rd_en}=2'b11，且empty时，直接dout<= din

除输出fifo使能外完成修改，已经找到流水思路

修改后尚未仿真

220304

* 仿真完成
* 加入了fifo透传模式
* outfifo.rd_en: 最后一个T对齐PE输出的最后一个outfifo.wr_en
  * outfifo.rd_en持续X个T
  * PE从第一个输入(cal_en上升沿)开始，到产生第一个输出，需要N+1个T；到产生最后一个输出，需要N+1+2(N-1)=3N-1个T
  * cal_en=westin[2].rd_en, westin[X].rd_en
  * 即：PE从westin[X].rd_en开始，到产生第一个输出，需要N个T；到产生最后一个输出，需要N+2(N-1)=3N-2个T
  * 所以，westin[X].rd_en的3N-2-(X-1)=3N-X-1级延迟，作为outfifo[1].rd_en
  *  outfifo[i].rd_en为outfifo[1].rd_en的i\*N级延迟，即westin[X].rd_en的(3+i)\*N-X-1级延迟
  * 总共需
* cal_en cal_done用reg？
* northfifo.rd_en目前是与westinfifo.rd_en一致 实际位宽可能不一样，还有循环的要求，要重新设计

晚上

* 加入fifo透传后，westin_fifo.rd_en还可以再提前几个周期
* 工作：
  * 最后一行输出的n_cal_en输出到northfifo.wr_en
  * westin.wr_en继续循环移位
  * southout->northinfifo.data_in, 由于可能出现线与，分别用Yin_val和n_cal_en作为三态门控制信号（写入，有效信号与数据同步，
* 所有参考以第一个为基准，可保证任意行都可使用
  * westin.wr_en: 根据输入
  * westin[1].rd_en: westin[1].wr_en的N*(X-1)+1级延迟
    * westin[i].rd_en：westin[1].rd_en的(i-1)级延迟
  * cal_en: westin[1].rd_en的一级延迟
  * outfifo[1].rd_en：westin[1].rd_en的3*N-2级延迟
    * outfifo[i].rd_en为outfifo[1].rd_en的i\*N级延迟，即westin[X].rd_en的(3+i)\*N-X-1级延迟



220305

* 移位使能：
  * northin：Yin_val的1+N级延迟
    * 1级：Yin_val下降沿后一个T，数据写入完成
    * N级：最后一个FIFO N级输出
  * westin

问题：

1. 

```verilog
		if(!sys_rst_n)  begin
            wr_addr <= {ADDR_WIDTH{1'b0}};
        end
```

赋值时是否一定要指明位宽?

* 赋0：时序上没有差别
* 加1：

2. 延迟链 是否要使能信号？（功耗与面积）
3. 输出 wire与reg？
4. 时序逻辑 即使检测下降沿



## 220315 新加功能

### 转置读出

按每一行读出到Yin即可

### **矩阵加法，减法：D=A*B+C**

C跟着A后面输入即可，在PE阵列的第一列完成相加

### PE逻辑

每一行有一条输出总线！这样就刚好可以连续输出

### **允许向PE阵列写入，允许从PE阵列读出信号**

### 对称矩阵



### 计算S

从左算到右比较复合



## 存储映射

协方差矩阵保存右上角

cov_vv, cov_vm: 保存全部值，共(3+2n)*3 总存于片上

临时变量：最大(3+2n * 2)

cov_mm: 保存右上角



### 计算量

N个特征点

cov_vv: 3* 3

cov_vm: 3 * 2n

cov_mm: 2n * 2n / 2 = 2n^2



## 220319

存储下三角：



## 220324

### 估算时间 确定PE维度

控制频率10Hz，数据关联频率低于控制频率，但需要在下一次输入控制向量前完成运算

也即：校正步最后的协方差矩阵更新需0.1s内完成

假设100Mhz 每次运算10^-8s

协方差矩阵更新

P：需校正的坐标点数

X：PE阵列维数，假设X=Y
$$
P\times \frac{(1+\frac{2N}{X})*\frac{2N}{X}}{2}\times 2Y = P\times (2N+\frac{4N^2}{X})
$$
令P=10 X=Y=4

有N<1000

假设频率能大于1000Hz，每次控制校正坐标点数<10，1000个特征点内4*4的PE阵列可以做到实时

### 估算存储

共4个bank，每个bank对应一个双端口RAM

假设一个数字存16bit，36Kbit的BRAM可存

### 存储调度

***使得可变维度n在m维***

这样，得到的输出也是依次到各个bank里，不管接下来是从A输入还是B输入，都可以直接对应bank过去

### cov_vv不好处理

最简单的操作：加一个处理，在**临时矩阵bank中加一个完整的cov_vv**

**该操作需在预测步/更新步最开始完成**

**额外的存储逻辑(不经过PE阵列，输入后寄存，然后输出到对应BANK)**

否则：需要额外的bank切换逻辑



适用于对称矩阵的PE阵列：

* 左下角输入
* 斜向传递，(3,2)->(2,3) (2,1)->(1,2) (3,1)->(2,2)->(1,3)

### cov_l不好处理(需折)

问题：特征点对应的两行需要转到对应的4个BANK中

* **预先读到临时BANK中**
* 计算cov_vl * H_T时，需切换A矩阵输入的COV_BANK 和 TEMP_BANK



### 端口处理

* M与C可用同一端口读/写，两者时间错开
* 上一轮的C为这一轮的A，输出C和输入A刚好错开，C A可共用端口
* 无关联关系，则A C需用不同端口

### 间隔

间隔指输入数据的间隔。读入数据需提前一个T写入地址，使能

两次输入：

* AC无数据关联：两次输入差2Y
* AC有数据关联：C输出的后一个

A输入--M输入：N+1

A输入--C输出：N+2

### 按特征点编号奇/偶数确定A C在BANK2,3 / BANK 1, 0

* X3可对应到A3/A0 C3/C0
* 考虑是否需要A也切换对应？

看K cov_HT是否需要蛇形存储！

* 可以不需要。顺序存储时只需要切换**输出端的BANK对应关系**即可
* 如果前级存储适合蛇形存储，则需变换TB输入端BANK对应关系

**切换输出端的BANK对应关系，即可实现cov_HT顺序存储**

## RTL

### RSA

FSM

* 控制输入输出的BANK连接

PE阵列连接关系

### PE_config

控制读写使能和地址

每次需要控制的量：



### PE_MAC

northin->southin

southout->northout

### AGD

输入(x,y) 生成对应读写地址

### in_sel(MUX)

相当于一级输入register

### out_sel(deMUX)

相当于一级输出register

### BRAM IP核

**没有开启**Primitives Output Register，改善时序。输出会在给出地址的后两个T再变化

CB：按498个特征点设计 总共4+996=1000行，共500250个数据，每个BANK需存125125个数据，CB_ADDR_WIDTH=19

TB：按498个特征点设计 总共32+8\*(1+2\*498/4)=2032, TB_ADDR_WIDTH=11

(未启用)16位地址 可存放723行 即



CB：按998个特征点设计 总共4+1996=2000行，每个BANK需存500250个数据，CB_ADDR_WIDTH=19

TB：按998个特征点设计 总共32+8\*(1+2\*998/4)=4032, TB_ADDR_WIDTH=12

(未启用)16位地址 可存放723行 即



### BRAM 读出：

wea ena addra同步

读出数据晚于地址1T

regdeMUX+regMUX 两级缓冲 2T

总计晚3T

### BRAM 写入：

地址晚于写入数据1T

web enb addrb同步



## FSM

第一级：大状态STAGE

* IDLE
* STAGE_PRD
* STAGE_NEW
* STAGE_UPD

输入：

* 握手信号 [2:0] stage_val, [2:0] stage_rdy
* stage_val由上位机发出。上位机写入完对应数据后，输出stage_val
  * PRD: stage_val = 'b001;
* stage_rdy由FPGA发出。
  * 当前PRD NEW UPD均在对应IDLE状态时，stage_rdy = 'b111
  * 均不在工作：stage_rdy = 'b000
* stage_val & stage_rdy
  * 'b000: unchanged
  * 'b001: PRD_handshake, go STAGE_PRD
  * defalut: multiple handshakes, go error

输出：

* stage_rdy

第二级：每一stage的不同算式

**整体用统一的计数器！**

**用计数值来确定PRD_1 -> PRD_2**

只有A[3] B[0] M[3] C[3] 受阶段控制，其余的均为移位

* A M C右移
* B 左移

#### 状态内部，输入输出来源改变。各BANK改变时间不同

* 以X BANK3 Y BANK0为基准设计，赋值
* **其他BANK通过移位实现！**



## 控制量

**由当前状态决定A[3] B[0] M[3] C[3], 其余均由移位链决定！**

### 由当前状态决定：

A_in_en：当前哪些行有效

B_in_en：当前哪些行有效

M_in_en：当前哪些行有效

C_out_en：当前哪些行有效

**当前保证到最慢的一个BANK也完成再切换。**

**如果只考虑最早BANK，en的切换需要根据状态的N级延迟决定**



A_in_sel_new：A数据来源。数据来源对于同一个

B_in_sel_new

M_in_sel_new

C_out_sel_new



TB_A_shift_ce：可使其一直保持移位（暂时接到了~sys_rst）

TB_ena_new

TB_wea_new

TB_douta_sel_new

TB_addra_new



TB_B_shift_ce：

TB_enb_new

TB_web_new

TB_dinb_sel_new

TB_doutb_sel_new

TB_addrb_new



### 移位决定

其余所有



## 只需保证最新的数据不冲突即可！



## 移位规则

### 控制量

sel ena wea：各BANK一致，直接移位即可

### 输入地址

TB：各BANK所需地址一致，直接移位即可

CB：各BANK所需**基址一致，偏移量不一致**，输入**基址移位**，在送入前需再加上偏移量

根据row[2]判断

row[2]=0: 地址对齐，直接移位即可

row[2]=1: 地址译码器得到A[3] / C[3]的地址

偏移量：

* 0: -2 -1 0
* 1: -1 0 1
* 2: 0 1 2
* 3: 1 2 3



## 各级数据缓冲，延迟

设置为parameter

* 输入addr_new到输入数据 addr_new_2_PEin
  * 4
* 输入数据到dout（M应有效的时间）
  * N+1
* dout到加法器输出结果 PEin_2_PEout
  * 1
* 加法器输出结果到RAM DIN：PEout_2_WRdin
  * 2
* Min到Cout RAM-IN：3
* addr_new到RAM DIN: 1 
* 写入地址与RAM DIN同时刻
* 给出行号到得到基址: ROW_2_BASE
  * 5

C：6级延迟(3 + 5 + 2 - 3)

从输入地址到给写入地址

* 输入地址到输入数据 3
* 输入数据到加法器输出结果 N+2=5
* 加法器输出结果到RAM DIN：2
* 写入地址与RAM DIN同时刻
* 给出行号到得到基址 -5

M：4级延迟

均为读取

从输入数据到得到dout N+1=4



## AGD

### 地址译码

进入各个阶段，先确定各行基址

表示为基址+偏移量

偏移量由计数值确定

流水系统中，后一级需要前一级的数据，这些数据均需要**随寄存器传递**

3级流水 100MHz

![image-20220401201123576](C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220401201123576.png)

4级流水，每一级都只进行一个操作 100MHz

![image-20220401202044332](C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220401202044332.png)

![image-20220401202113895](C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220401202113895.png)

4级流水 200MHz

![image-20220401202721098](C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220401202721098.png)



### 220406

* 不再区分ena_rd/ ena_wr
  * 无论读还是写，都需要经过移位

### 220407

* dshift 考虑放到RSA.v 这样config就只用输出reg A_in_sel_new, 不会出现输出端口为wire类型的情况

### 220408

* 要多个相同IP核就只能多次生成。不能对一个IP核多次实例化

<img src="C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220408184451736.png" alt="image-20220408184451736" style="zoom:50%;" />

Port A Options Output Registers 是在读数据输出后面接一个寄存器打一拍，其中 **Primitives Output Register** 是使用BRAM内部自带的缓冲器打拍，这个缓冲器的数据打入触发器的时间延迟比较大，在高速设计中**可能会引起时序违例**，优点是在**低速应用中充分应用BRAM内部资源，节约LUT资源**；其中 **Core Output Register** 是使用**LUT搭建的缓冲器**，这个**缓冲器的延迟较小，适合高速设计中使用**；由于RAM IP核的自身设计结构问题，RAM数据输出总是迟于地址一个读时钟周期，即输出数据在RAM内部就被打了一拍，如果上述两个缓冲器勾了一个，那输出数据就是打两拍，如果两个缓冲器都勾上了，那最后输出数据就是打三拍
————————————————
原文链接：https://blog.csdn.net/qq_40807206/article/details/109685727

点击 Other Options ，可以看到一个 Coe File 和 Fill Remaining Memory Locations ，其中 Coe File  是类似于Altera中的mif文件一样的用途，用于**初始化RAM中的初始数据**，如果不需要初始化RAM中的数据或者都想初始化成0，那么可以勾选下面的 **Fill Remaining Memory Locations**  ，代表将**所有未被初始化的RAM空间都设定为后面输入框中的值**（十六进制表示）
————————————————
原文链接：https://blog.csdn.net/qq_40807206/article/details/109685727

[(1条消息) 在Git的多个分支同时开发_weixin_38872524的博客-CSDN博客_git多分支 并行开发](https://blog.csdn.net/weixin_38872524/article/details/108885913)

### 220409

* 为每个generate块定义单独的genvar。且genvar在generate块内定义
  * 把genvar定义在generate之外的话，两个generate都使用了这个变量，那么编译/lint/nlint都不会报错，甚至warning都不会报出，但是却可能引起仿真陷入死循环，也是不推荐，就乖乖定义genvar好了；
  * [(1条消息) 【Verilog】generate和for循环的一些使用总结（1）_尼德兰的喵的博客-CSDN博客_generate](https://blog.csdn.net/moon9999/article/details/106969615)
* 多驱动问题
  * 查找代码，没有重复赋值
  * 尝试如上措施。不再报错
* 修改NEW_addr2PEin
  * 读取：A B相关的下移一个时钟
  * 如果在addr_new -> addr增加延迟，则C输出写入也要提前
* 利用对称性：
  * **让奇数组BANK3的数据，偶数组BANK0的数据先算**
    * 即：BANK3：row 3 11 ...
    * BANK0：7 15 ...
  * **输入不改变次序，输出改变次序，传入不同BANK**
  * 若考虑CB有对称性，需要让CB_3接westin[0]
  * 但CB对称部分不会输出作为A输入，因此**仍让CB_3接westin[3]**
  * TB由于不占满4个BANK的情况，**TB_0接westin[0]，TB_3接westin[3]**
  * 且TB各BANK每次的地址相同；CB各BANK偏移量不同
  * UPD_LAST的输出只需要**对M C输出做交换即可**
* ena wea 需要额外延迟：各延迟一致，直接在dshift.v文件里加延迟
* CB_addr：**直接由CB_AGD模块输出各个位对应的地址！**
  * 恰好每个BANK需要地址的时刻是错开一个T的！
* **四排不够，由于空余的两行都是0，加进来一起算**
* 两次输入间隔为2Y，固定！
  * 预测，新地标初始化，更新，均为读取cov_mv
  * 因此，cov_mv可以设计专门的地址译码模块
  * 其他要用到的地方
    * cov_l：需设计专用模块读出
    * cov：从头读到尾即可

### 220411

* 读各级延迟后的group_cnt_d，判断是否需要递增！
* 先检查代码逻辑！

### 220416

* IBUFDS
* NEW: cov_vm从B输入，需要调换顺序，以保证输出的顺序正确
* CB 输出地址移位
  * group_cnt_0 == 1’b0：为右移（让BANK3先输出），需写相应的偏移量控制
  * group_cnt_0 == 1’b1: 保持不变
* CB-portA 需切换左移/右移
* CB_douta_sel A_in_sel 更改

### 220420

* A B M设正反输入模式
* C设全映射模式
* 由于最后一步更新，各行切换时刻不同，因此**不能用统一的大MUX**，只能每一行有单独的deMUX MUX，使能端由移位控制
* 修改结构
  * 结构实例化本身
  * 控制信号位宽
  * 已有运算步骤的输入、输出控制量
* UPD_LAST
  * 不能仅通过改变输出分配实现接续输出
    * 始终要是数据量大的行先算(3 7 11 15)
    * 会有数据冲突
  * CAL_EN有效之外，各PE单元只会传递数据
  * 利用该性质，设计AB蛇形输入（A B恰好也与BANK对应上了），可以实现
  * 即:A BANK3，算完上一轮第一个后，开始下一轮的整行计算
* 要先算的行：
  * 3 11 19：在BANK3
  * 7 15 23：在BANK0
  * 通过映射修改先算的行！

### 220422

* PE切换数据流：B矩阵可从两个方向进入

* west 从上至下为BANK 0~3, north 从左至右为BANK 0~3

* 方块矩阵：A从west BANK0开始，B从north BANK0开始

* 下三角矩阵：

  * 奇数group(group_num[0] = 1): A从west BANK3开始输入，B从south BANK0开始输入
    * A：右移，反向映射
    * B：左移，正向映射，south输入
  * 偶数group(group_num[0] = 0): A从west BANK0开始，B从north BANK0开始
    * A：左移，正向映射
    * B：左移，正向映射，north输入
  * M C：右移，正向映射

* IOBUF

  * 直接编写RTL：

  * 在Xilinx中一个IOBUF资源默认T端为0时IO端才为输出，T端为1时，IO端为输入，

    ```verilog
    module inout_top
    (
    input       I_data_in        ,
    inout       IO_data          ,
    output     O_data_out     ,
    input       Control
    );
    
    wire I_data_in;
    wire O_data_out;
        
    assign IO_data = (Control == 1’b0) ? I_data_in : 1'bz ;
    assign O_data_out = IO_data ;
    
    endmodule    
    ```

    

  * 调用原语：

  ```verilog
  module inout_top
  (
  input   I_data_in,
  inout   IO_data  ,
  output  O_data_out  ,
  input   Control
  );
  
  IOBUF #(
    .DRIVE(12), // Specify the output drive strength
    .IBUF_LOW_PWR("TRUE"),  // Low Power - "TRUE", High Performance = "FALSE"
    .IOSTANDARD("DEFAULT"), // Specify the I/O standard
    .SLEW("SLOW") // Specify the output slew rate
  ) IOBUF_inst (
    .O(O_data_out),     // Buffer output
    .IO(IO_data),   // Buffer inout port (connect directly to top-level port)
    .I(I_data_in),     // Buffer input
    .T(Control)      // 3-state enable input, high=input, low=output
  );
  
  endmodule
  ```

  <img src="C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220422110643683.png" alt="image-20220422110643683" style="zoom:25%;" />

<img src="C:\Users\KevinZ\AppData\Roaming\Typora\typora-user-images\image-20220422111124294.png" alt="image-20220422111124294" style="zoom:50%;" />

原语中的O/I都是针对这个BUF来说的，不是针对管脚，务必注意。

*  .IO() 端口对应inout端口

* 模块输入input填入到 .I()，.T()有效时通过OBUF缓冲输出到.IO()管脚；

* 模块输出output填入到.O(), 从.IO()管脚输入进来的信号经过IBUF缓冲到 .O()

* 输入信号想要正确，那么这个时候的OBUF必须是高阻z，也就是 .T()要有效。

* 所以 .T() 填管脚input的使能条件，即让输出无效，这里是read。

原语只支持一个信号的处理，如果处理多位总线，需要用到循环语句。

```verilog
genvar i;
generate
    for(i=0;i<8;i=i+1)
        begin
            // iobuf
         end
endgenerate
```



## 运算指令集

输入和输出分开

**A B M C移位方向由PE_mode决定！**

**TB CB移位方向、地址移位方向由数据映射决定**!

### 运算输入配置

m, n, k

cal_mode[11:0]

* A来源(A_in_en, A_in_sel_new)
  * 00: TB
  * 10: CB
* B来源(B_in_en, B_in_sel_new)
  * 00: TB
  * 01: TB_cache
  * 10: CB
* M来源(M_in_en, M_in_sel_new)
  * 00: TB
  * 10: CB
* C去向(C_in_en, C_in_sel_new)
  * 00: TB
  * 01: TB_cache
  * 10: CB
* adder_mode
  * 00: NONE
  * 01: ADD
  * 10: C_MINUS_M
  * 11: M_MINUS_C
* PE_mode(dir)
  * N_W, S_W, ...

### TB CB译码控制量

* TBa_mode

  * 配置模式[4:2]
    * 3’b001: A
    * 3'b010: M
    * 3'b011: A+M
    * 3'b100: non_linear写入
  * 顺序 [1:0]
    * POS：01
    * NEG：10
    * NEW：11
* TBb_mode

  * 配置模式[4:2]
    * 3'b001: B
    * 3’b010: C
    * 3'b100: B_cache
    * 3'b011: B+C
  * 顺序 [1:0]
    * POS：01
    * NEG：10
    * NEW：11
* CBa_mode

  * 配置模式[4:2]
    * 3’b001: A
    * 3'b010: B
    * 3'b100: M
  * 顺序 [1:0]
    * POS：01
    * NEG：10
    * NEW：11
* CBb_mode

  * 配置模式[4:2]
    * 3'b001: C
    * 3’b010: 
    * 3'b100: non_linear读取
  * 顺序 [1:0]
    * POS：01
    * NEG：10
    * NEW：11

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

以addr_new为参考(addr_new对应到seq_cnt=0)

RD_2_WR_D: 7(1 + 4 + 2)

* 1: A_addr_new -> A_addr[0]
* 4: A_addr[0] -> A_data
* N + 2 : A_data -> C_data
* 1：C_data -> C_addr_new
* 1: C_addr_new -> C_addr[0]

N=1时，C_addr_new为A_addr_new 的8级延迟

N=2时，C_addr_new为A_addr_new 的9级延迟

N=3时，C_addr_new为A_addr_new 的10级延迟

N=5时，C_addr_new为A_addr_new 的12级延迟



M_addr_new为A_addr_new的N+1级延迟



### 方向控制量：

CBa_shift_dir: CBa_mode[1:0]

CB_douta_sel_shift: CBa_mode[1:0]的2级延迟



A_in_sel_shift_dir, B_in_sel_shift_dir: cal_mode的NEW_2_A_sel(3)级延迟

PE_mode, cal_en, cal_done: cal_mode的NEW_2_PE_in(4)级延迟

M_in_sel_dir, M_adder_mode: cal_mode的NEW_2_PE_in+N+1级延迟，将延迟固定为7

C_out_sel_dir: cal_mode的NEW_2_PE_in+N+2级延迟，将延迟固定为8



CB_dinb_shift: CBb_mode[1:0]的NEW_2_PE_in+N+3级延迟，固定为9

CBb_shift_dir：CBb_mode[1:0]的NEW_2_PE_in+N+3级延迟，固定为9

NEW_2_PE_in+N+4 T后，数据输入到CB_dinb；同时addrb应有效 

addrb_new: NEW_2_PE_in+N+3

### 读取时序

0：配置

1：给new, CBa_shift_dir，PE_mode

2：addr[0]

3：addr[1]	CB_douta[0]

4：addr[2]	CB_douta[1]	B_CB_douta[0]

5：addr[3]	CB_douta[2]	B_CB_douta[1]	northin[0]

0：配置		 

1：给new

结论：

* CBa_shift_dir可以保证en we addr正确移位、送入   即：一个seq_cnt周期内，CBa_shift_dir一直为该段对应的值。这也保证了后面只需通过延迟，即可保证每一行都为正确的方向。无需每一行的移位都独立检查上一行的移位方向
* **CB_douta_sel的方向应为CBa_shift_dir的2级延迟** 
*  **A_in_sel, B_in_sel的方向应由PE_mode的3级延迟决定。**
* **实际PE_array的mode应为控制量PE_mode的4级延迟**

**TB同理。TB CB延迟一致**

### 写入时序

#### TB

* M_in_sel， M_adder_mode 应为PE_mode的1+NEW_2_PE_in+N+1级延迟，将延迟固定为7
* C_out_sel由PE_mode的 1+NEW_2_PE_in+N+2级延迟决定  由于PE_mode会持续技术时间，将延迟固定为8
* 写地址和写数据同步
* 因此TB_dinb_sel的方向无需延迟


### 输出控制量

* BRAM
  * en_new
  * we_new
  * addr_new
  * shift 移位方向（由来源、去向决定）
* BRAM-out MUX&deMUX
  * 选择信号
* PE array MUX&deMUX
  * A_in_sel_new
  * B_in_sel_new
  * M_in_sel_new
  * C_out_sel_new
  * M_adder_mode
* PE array
  * PE_mode





### 220429

* CB_AGD:
  * 只生成BANK0对应的每行首地址
  * 实际使用，也是在第一周期，使得CB_addra_new <= CB_addra_base
  * 因此：CB_addra_base 应得到(0,0) (7,0) (8,0) (15,0)的地址，从而可读state！
* CB_addr_shift
  * 

#### TBD：

* non_linear 
  * CB-B read
  * TB-A write
* CB_2_TB
  * CB-B read
  * TB-A write

### 220430

* NEW_3的读取按最坏情况计算，否则需改变shift顺序
* 考虑把shift也放到map中？



### 220510

* prd_cnt的归零值也可设置为寄存器
* 移位控制量也应是输入的dir的移位



### 输入时序

0：配置

1~n：输入A B addr_new 共n个

1+(N+1): 输入M 共n个

### 输出时序

* TB输出：时序由seq_cnt决定
  * 1+NEW_2_PEin + N+2 + ADDER2_NEW=11
  * 1：输入第一个addr_new的时刻
  * NEW_2_PEin=4：addr_new到输入第一个数据
  * N+2: 计算用时
  * ADDER_NEW=1：加法结果到给写入addr_new
* CB输出：
  * 由专门的out、_cnt决定
  * 每两个一输出：根据cnt[0]=0/1决定
  * 由config中的控制单元确定要读多少个，算出对应的addr_new(由addr_base递增)
    * cov_vm: 3
    * cov_l: 2*landmark_num+1
    * cov_ll: 2
    * cov: 2*landmark_num+3

  * addr_shift只管映射



### problems

* 现在的TB CB sel无需移位，只有一个
  * 注意：RSA中的sel应为config输出的sel_new的一级缓存
* landmark_num_10
* cal_en_new, cal_done_new
* group_cnt起始0在何处？相应的尚未更改
  * 暂时设定：ROW4~7为group_0 应反向

## 220503 改存储方案！

* addr_shift: CB的地址也是对齐的，直接移位即可
* group_cnt: 在进入该group就先+1, 中间给了en信号才会计算出新的base_addr
* CB_base_AGD：
  * **模式0：计算group_cnt+1的首地址**
  * 模式1：计算group_cnt的首地址
  * **cov_vv直接赋地址1 2 3**
* 注意：CBb 使用延迟后的group_cnt

### problems

* CB-A:
  * '1 addr_dir
  * '2: out_sel
* CB-B
  * '0: in_sel
  * '1 addr_dir

### 终止条件

#### PRD

* 由landmark_num计算group_cnt_max
  * group_cnt_max = (landmark_num+1) >> 1
  * 最后一个group 不齐 算完就行了

#### NEW

* **完成后**再landmark_num <= landmark_num + 1
* 由landmark_num计算group_cnt_max（CB-A读取）
  * 当前最后一个group齐（landmark_num[0]=0, 新地标l_k[0]=1）
    * 正常
  * 当前最后一个group不齐（landmark_num[0]=1, 新地标l_k[0]=0）
    * 算完最后一个。最后cov_ll可覆盖
* 由l_k计算该新地标对应的首地址（CB-B写入）
  * **进NEW UPD模式就算好**
  * l_k_group <= (l_k+1) >> 1
  * l_k_group_base
  * 得到该列首地址
* cov_lv
  * l_k_group_base + 2*(l_k+1) = l_k_group_base + l_k<<1 + 2



### problems

* **PE array使能条件**
* B_cache
* 需在group_cnt更新时采样基址
* group_cnt更新后4T输出新基址

### 改组合逻辑 查找表设置模式（提前一个T）

* TB CB读写逻辑修改
* TB_base_addr如何递增？
  * 应使用时序赋值。但好像来不及
  * **采样？**
* 分离TB-B输入，输出
  * 输出用延迟后的cnt等

### not complished

* TB_addr_base需递增：
  * 组合逻辑赋最初的值TB_addr_base_raw
  * 在seq_cnt == seq_cnt_max时，递增+4
* 需递增的内容：
  * UPD_2: 
    * C: cov_HT
  * UPD_3:
    * A: t_cov_l
  * UPD_6
    * A: cov_HT
    * C: K
  * UPD_7
    * A: K
    * B: cov_HT
* **采用的递增方案：**
  * 设置addr_base_set
  * 再计算addr_base
  * 第一个group用addr_base_set
* **cov_l -> t_cov_l**
* **cache**
  * 特殊的RAM
    * 深度为5
    * 写: 地址从0开始递增，wr_addr=4则令wr_addr=0
    * 读: 地址从0开始递增，rd_addr=4则令rd_addr=0
  * 写：
    * 按照时序给addr en we
  * 读：
    * 模式：组合逻辑切换
    * 按照时序输出addr en we
* **cov_HT转换**
  * 并转串
* **求逆**
  * 再UPD_5时序内完成求逆
* 都换为2位dir



### 220506 ToDo

* TB_doutb_map
  * CONS转换
* CB_douta_map
  * cov_l转换映射
  * sel
* new: TB_dina_map
* TBa: 分离AM；TBb: 分离BC
* 改回DIR_NEW, 需传入l_k[0]
* UPD 的M N K, 转移条件

### cov_vv存于BANK012 or BANK123?

* 若存于BANK123， 每次更新会把BANK0的state一并更新（先从BANK1开始存。要额外的控制）
* 因此，cov_vv存于BANK012 state存于BANK3
* 要改变的地方：（已完成）
  * cov_vv读取
  * cov_vv cov_vm cov_lv需区分



### 220508

* dynamic_shreg 可实现！
