  `define  TB_POS = 3'b000;
  `define  TB_NEG = 3'b001;
  `define  CB_POS = 3'b010;
  `define  CB_NEG = 3'b011;

  //新地标初始化步，根据landmark后两位决定映射关系(进NEW步骤就先+1)
  /*
    l_num[1:0]  CB_BANK   C_data
    11          0         0
                1         1 
                
    00          2         0
                3         1

    01          3         0
                2         1

    10          1         0
                0         1
  */
  `define  DIR_NEW_11  = 3'b111; 
  `define  DIR_NEW_00  = 3'b100;
  `define  DIR_NEW_01  = 3'b101;
  `define  DIR_NEW_10  = 3'b110;
