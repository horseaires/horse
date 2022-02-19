--Copyright (C)2014-2021 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: GowinSynthesis V1.9.8
--Part Number: GW2A-LV18PG484C8/I7
--Device: GW2A-18
--Created Time: Mon Nov 15 10:08:49 2021

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component fifo_pong
	port (
		Data: in std_logic_vector(15 downto 0);
		Reset: in std_logic;
		WrClk: in std_logic;
		RdClk: in std_logic;
		WrEn: in std_logic;
		RdEn: in std_logic;
		Almost_Empty: out std_logic;
		Almost_Full: out std_logic;
		Q: out std_logic_vector(15 downto 0);
		Empty: out std_logic;
		Full: out std_logic
	);
end component;

your_instance_name: fifo_pong
	port map (
		Data => Data_i,
		Reset => Reset_i,
		WrClk => WrClk_i,
		RdClk => RdClk_i,
		WrEn => WrEn_i,
		RdEn => RdEn_i,
		Almost_Empty => Almost_Empty_o,
		Almost_Full => Almost_Full_o,
		Q => Q_o,
		Empty => Empty_o,
		Full => Full_o
	);

----------Copy end-------------------
