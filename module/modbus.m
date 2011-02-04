# Modbus protocol
#
# Copyright (C) 2011, Corpus Callosum Corporation.  All Rights Reserverd.

Modbus : module
{
	PATH:		con "/dis/lib/modbus.dis";

	MAXPDUSZ:	con 253;
	
	ModeRTU,
	ModeASCII,
	ModeTCP,
	Maxmode:	con iota;
	
	# Function codes
	Readcoils,				# 0x01
	Readdiscrete,
	Readholding,
	Readinput,
	Writecoil,
	Writeregister,
	Readexception,
	Diagnostics:			con (1+iota);
	CommEventCounter,		# 0x0B
	CommEventLog:			con (16r0B+iota);
	WriteCoils,				# 0x0F
	WriteRegisters,
	SlaveID:				con (16r0F+iota);
	ReadFileRecord,			# 0x14
	WriteFileRecord,
	MaskWriteRegister,
	RWRegisters,
	ReadFIFO:				con (16r14+iota);
	EncapsulateInterTransport:	con (16r2B);
	Fmax:	con (16r2C);
	
	# sub-function codes (Diagnostics)
	ReadQueryData,			# 0x00
	RestartCom,
	DiagnosticRegister,
	ChangeInputDelimiter,
	ForceListenOnly:		con byte (iota);
	Clear,					# 0x0A  Clear counters and diagnostic register
	BusMessageCount,
	BusCommErrCount,
	BusExceptionErrCount,
	SlaveMessageCount,
	SlaveResponseCount,
	SlaveNAKCount,
	SlaveBusyCount,
	BusOverrunCount:		con byte(16r0A+iota);
	ClearOverrunCounter:	con byte(16r14);
	
	# MEI Type Interface transport
	CANopen:				con byte(16r0D);
	DeviceID:				con byte(16r0E);
	
	Code: adt {
		code: int;
		text: string;
	};


	Terror,		# not used
	Rerror,
	Treadcoils,
	Rreadcoils,
	Treaddiscreteinputs,
	Rreaddiscreteinputs,
	Treadholdingregisters,
	Rreadholdingregisters,
	Treadinputregisters,
	Rreadinputregisters,
	Twritecoil,
	Rwritecoil,
	Twriteregister,
	Rwriteregister,
	Treadexception,
	Rreadexception,
	Tdiagnostics,
	Rdiagnostics,
	Tcommeventcounter,
	Rcommeventcounter,
	Tcommeventlog,
	Rcommeventlog,
	Twritecoils,
	Rwritecoils,
	Twriteregisters,
	Treadregisters,
	Tslaveid,
	Rslaveid,
	Treadfilerecord,
	Rreadfilerecord,
	Twritefilerecord,
	Rwritefilerecord,
	Tmaskwriteregister,
	Rmaskwriteregister,
	Trdwrregisters,
	Rrdwrregisters,
	Treadfifo,
	Rreadfifo,
	Tencapsulatedinterface,
	Rencapsulatedinterface,
	Tmax:	con iota;
	
	Mmsg: adt {
		tid: int;
		pick {
		Treadcoils =>
		Treaddiscreteinputs =>
		Treadholdingregisters =>
		Treadinputregisters =>
			offset: int;		# 2 bytes
			count:	int;		# 2 bytes
		Twritecoil =>
		Twriteregister =>
			offset: int;		# 2 bytes
			value:	int;		# 2 bytes
		Tdiagnostics =>
			subf:	int;		# 2 bytes
			data:	int;		# 2 bytes
		
		Twritecoils =>
		Twriteregisters =>
			offset: int;		# 2 bytes
			quantity: int;		# 2 bytes
			count:	byte;		# N
			value:	array of byte;

		Rreadcoils =>
		Rreaddiscreteinputs =>
		Rreadholdingregisters =>
		Rreadinputregisters =>
			count:	byte;
			status:	array of byte;
		Rwritecoil =>
		Rwriteregister =>
		Rwritecoils =>
		Rwriteregisters =>
			offset:	int;		# 2 bytes
			value:	int;		# 2 bytes
		Rdiagnostics =>
			subf:	int;
			data:	int;
				
		Treadexception =>
		Tcommeventcounter =>
		Tcommeventlog =>
		Tslaveid =>
		Rerror =>
			e:		string;
			
		Rreadexception =>
			r:		byte;
		Rcommeventcounter =>
			status:	int;		# 2 bytes
			ecount:	int;		# 2 bytes
		
		Rcommeventlog =>
			count:	byte;
			status:	int;		# 2 bytes
			ecount:	int;		# 2 bytes
			mcount:	int;		# 2 bytes
			events:	array of byte;
		
		Rslaveid =>
			count:	byte;
			value:	array of byte;
			status:	byte;
			
		Treadfilerecord =>
		Twritefilerecord =>
		Rwritefilerecord =>
			count:	byte;
			filenum:	int;	# 2 bytes
			recnum:		int;	# 2 bytes
			rlength:	int;	# 2 bytes
			data:	array of byte;
			
		Rreadfilerecord =>
			count:	byte;
			rlength:	byte;
			data:	array of byte;
		
		Tmaskwriteregister =>
		Rmaskwriteregister =>
			offset:	int;		# 2 bytes
			andmask:	int;	# 2 bytes
			ormask:	int;		# 2 bytes

		Trdwrregisters =>
			roffset:	int;
			rcount:	int;
			woffset:	int;
			wcount:	int;
			count:	byte;
			data:	array of byte;
		
		Rrdwrregisters =>
			count:	byte;
			data:	array of byte;
			
		Treadfifo =>
			offset:	int;
		
		Rreadfifo =>
			count:	int;		# 2 bytes
			fcount:	int;
			data:	array of byte;
			
		Tencapsulatedinterface =>
		Rencapsulatedinterface =>
			meitype: byte;
			data:	array of byte;
		}
		
		read:	fn(fd: ref Sys->FD): (ref Mmsg, string);
		unpack:	fn(a: array of byte): (int, ref Mmsg);
		pack:	fn(nil: self ref Mmsg): array of byte;
		packedsize:	fn(nil: self ref Mmsg): int;
		text:	fn(nil: self ref Mmsg): string;
	};
		
	init:	fn();
	
	readmsg:	fn(fd: ref Sys->FD, msize: int): (array of byte, string);
};
