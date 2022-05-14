# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"


}

proc update_PARAM_VALUE.A_IN_SEL_DW { PARAM_VALUE.A_IN_SEL_DW } {
	# Procedure called to update A_IN_SEL_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.A_IN_SEL_DW { PARAM_VALUE.A_IN_SEL_DW } {
	# Procedure called to validate A_IN_SEL_DW
	return true
}

proc update_PARAM_VALUE.B_IN_SEL_DW { PARAM_VALUE.B_IN_SEL_DW } {
	# Procedure called to update B_IN_SEL_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.B_IN_SEL_DW { PARAM_VALUE.B_IN_SEL_DW } {
	# Procedure called to validate B_IN_SEL_DW
	return true
}

proc update_PARAM_VALUE.CB_AW { PARAM_VALUE.CB_AW } {
	# Procedure called to update CB_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CB_AW { PARAM_VALUE.CB_AW } {
	# Procedure called to validate CB_AW
	return true
}

proc update_PARAM_VALUE.C_OUT_SEL_DW { PARAM_VALUE.C_OUT_SEL_DW } {
	# Procedure called to update C_OUT_SEL_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_OUT_SEL_DW { PARAM_VALUE.C_OUT_SEL_DW } {
	# Procedure called to validate C_OUT_SEL_DW
	return true
}

proc update_PARAM_VALUE.L { PARAM_VALUE.L } {
	# Procedure called to update L when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.L { PARAM_VALUE.L } {
	# Procedure called to validate L
	return true
}

proc update_PARAM_VALUE.M_IN_SEL_DW { PARAM_VALUE.M_IN_SEL_DW } {
	# Procedure called to update M_IN_SEL_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.M_IN_SEL_DW { PARAM_VALUE.M_IN_SEL_DW } {
	# Procedure called to validate M_IN_SEL_DW
	return true
}

proc update_PARAM_VALUE.ROW_LEN { PARAM_VALUE.ROW_LEN } {
	# Procedure called to update ROW_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ROW_LEN { PARAM_VALUE.ROW_LEN } {
	# Procedure called to validate ROW_LEN
	return true
}

proc update_PARAM_VALUE.RSA_DW { PARAM_VALUE.RSA_DW } {
	# Procedure called to update RSA_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RSA_DW { PARAM_VALUE.RSA_DW } {
	# Procedure called to validate RSA_DW
	return true
}

proc update_PARAM_VALUE.SEQ_CNT_DW { PARAM_VALUE.SEQ_CNT_DW } {
	# Procedure called to update SEQ_CNT_DW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SEQ_CNT_DW { PARAM_VALUE.SEQ_CNT_DW } {
	# Procedure called to validate SEQ_CNT_DW
	return true
}

proc update_PARAM_VALUE.TB_AW { PARAM_VALUE.TB_AW } {
	# Procedure called to update TB_AW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TB_AW { PARAM_VALUE.TB_AW } {
	# Procedure called to validate TB_AW
	return true
}

proc update_PARAM_VALUE.X { PARAM_VALUE.X } {
	# Procedure called to update X when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.X { PARAM_VALUE.X } {
	# Procedure called to validate X
	return true
}

proc update_PARAM_VALUE.Y { PARAM_VALUE.Y } {
	# Procedure called to update Y when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.Y { PARAM_VALUE.Y } {
	# Procedure called to validate Y
	return true
}


proc update_MODELPARAM_VALUE.X { MODELPARAM_VALUE.X PARAM_VALUE.X } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.X}] ${MODELPARAM_VALUE.X}
}

proc update_MODELPARAM_VALUE.Y { MODELPARAM_VALUE.Y PARAM_VALUE.Y } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.Y}] ${MODELPARAM_VALUE.Y}
}

proc update_MODELPARAM_VALUE.L { MODELPARAM_VALUE.L PARAM_VALUE.L } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.L}] ${MODELPARAM_VALUE.L}
}

proc update_MODELPARAM_VALUE.A_IN_SEL_DW { MODELPARAM_VALUE.A_IN_SEL_DW PARAM_VALUE.A_IN_SEL_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.A_IN_SEL_DW}] ${MODELPARAM_VALUE.A_IN_SEL_DW}
}

proc update_MODELPARAM_VALUE.B_IN_SEL_DW { MODELPARAM_VALUE.B_IN_SEL_DW PARAM_VALUE.B_IN_SEL_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.B_IN_SEL_DW}] ${MODELPARAM_VALUE.B_IN_SEL_DW}
}

proc update_MODELPARAM_VALUE.M_IN_SEL_DW { MODELPARAM_VALUE.M_IN_SEL_DW PARAM_VALUE.M_IN_SEL_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.M_IN_SEL_DW}] ${MODELPARAM_VALUE.M_IN_SEL_DW}
}

proc update_MODELPARAM_VALUE.C_OUT_SEL_DW { MODELPARAM_VALUE.C_OUT_SEL_DW PARAM_VALUE.C_OUT_SEL_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_OUT_SEL_DW}] ${MODELPARAM_VALUE.C_OUT_SEL_DW}
}

proc update_MODELPARAM_VALUE.RSA_DW { MODELPARAM_VALUE.RSA_DW PARAM_VALUE.RSA_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RSA_DW}] ${MODELPARAM_VALUE.RSA_DW}
}

proc update_MODELPARAM_VALUE.TB_AW { MODELPARAM_VALUE.TB_AW PARAM_VALUE.TB_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TB_AW}] ${MODELPARAM_VALUE.TB_AW}
}

proc update_MODELPARAM_VALUE.CB_AW { MODELPARAM_VALUE.CB_AW PARAM_VALUE.CB_AW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CB_AW}] ${MODELPARAM_VALUE.CB_AW}
}

proc update_MODELPARAM_VALUE.SEQ_CNT_DW { MODELPARAM_VALUE.SEQ_CNT_DW PARAM_VALUE.SEQ_CNT_DW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SEQ_CNT_DW}] ${MODELPARAM_VALUE.SEQ_CNT_DW}
}

proc update_MODELPARAM_VALUE.ROW_LEN { MODELPARAM_VALUE.ROW_LEN PARAM_VALUE.ROW_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ROW_LEN}] ${MODELPARAM_VALUE.ROW_LEN}
}

