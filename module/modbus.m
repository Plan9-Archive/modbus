# Modbus protocol
#
# Copyright (C) 2011, Corpus Callosum Corporation.  All Rights Reserverd.

Modbus : module
{
	PATH:		con "/dis/lib/modbus.dis";

	BIT8SZ:	con 1;
	BIT16SZ:	con 2;

	MBAPSZ:		con 7;
	
	MAXPDUSZ:	con 253;
	MAXRTUADUSZ:	con BIT8SZ+MAXPDUSZ+BIT16SZ;
	MAXTCPADUSZ:	con MAXPDUSZ+MBAPSZ;
	
	ModeRTU,
	ModeTCP,
	Maxmode:	con iota;
	
	# Function code types
	Treadcoils,				# 0x01
	Treaddiscreteinputs,
	Treadholdingregisters,
	Treadinputregisters,
	Twritecoil,
	Twriteregister,
	Treadexception,
	Tdiagnostics:			con (1+iota);
	Tcommeventcounter,		# 0x0B
	Tcommeventlog:			con (16r0B+iota);
	Twritecoils,				# 0x0F
	Twriteregisters,
	Tslaveid:				con (16r0F+iota);
	Treadfilerecord,			# 0x14
	Twritefilerecord,
	Tmaskwriteregister,
	Trwregisters,
	Treadfifo:				con (16r14+iota);
	Tencapsulatedtransport,
	Tmax:					con (16r2B+iota);
	
	# sub-function codes (Diagnostics)
	TDreadquerydata,			# 0x00
	TDrestartcom,
	TDdiagnosticregister,
	TDchangeinputdelimiter,
	TDforcelistenonly:		con byte (iota);
	TDclear,					# 0x0A  Clear counters and diagnostic register
	TDbusmessagecount,
	TDbuscommerrcount,
	TDbusexceptionerrcount,
	TDslavemessagecount,
	TDslaveresponsecount,
	TDslavenakcount,
	TDslavebusycount,
	TDbusoverruncount:		con byte(16r0A+iota);
	TDclearoverruncounter:	con byte(16r14);
	
	# MEI Type Interface transport
	TMcanopen:				con byte(16r0D);
	TMdeviceid:				con byte(16r0E);
	
	
	TMmsg: adt {
		fcode: int;
		pick {
		Readerror =>
			error: string;					# tag/fcode is unused in this case
		Readcoils =>
			offset:	int;					# 2	bytes, 0x0000 to 0xFFFF
			quantity: int;					# 2 bytes, 0x0001 to 0x07D0
		Readdiscreteinputs =>
			offset: int;
			quantity: int;
		Readholdingregisters =>
			offset: int;
			quantity: int;					# 2 bytes, 0x0001 to 0x007D
		Readinputregisters =>
			offset: int;
			quantity: int;					# 2 bytes, 0x0001 to 0x007D
		Writecoil =>
			offset: int;
			value: int;						# 2 bytes 0x0000 or 0xFF00
		Writeregister =>
			offset: int;
			value: int;						# 2 bytes 0x0000 to 0xFFFF
		Readexception =>
			s: string;						# not used
		Diagnostics =>
			subf: int;						# 2 bytes, sub-function type
			data: int;						# 2 bytes
		Commeventcounter =>
			s: string;						# not used
		Commeventlog =>
			s: string;						# not used
		Writecoils =>
			offset: int;
			quantity: int;
			count: int;
			data: array of byte;
		Writeregisters =>
			offset: int;
			quantity: int;					# 2 bytes, 0x0001 to 0x007B
			count:	int;					# 1 byte
			data: array of byte;
		Slaveid =>
			s: string;						# not used
		Readfilerecord =>
			count: int;						# 1 byte, 0x07 to 0xF5
			data: array of byte;
		Writefilerecord =>
			count: int;						# 1 byte, 0x09 to 0xFB
			data: array of byte;
		Maskwriteregister =>
			offset: int;					# 2 bytes
			andmask: int;					# 2 bytes
			ormask: int;					# 2 bytes
		Rwregisters =>
			roffset: int;					# 2 bytes
			rquantity: int;					# 2 bytes
			woffset: int;					# 2 bytes
			wquantity: int;					# 2 bytes
			count:	int;					# 1 byte
			data:	array of byte;			# 2 * count
		Readfifo =>
			offset: int;
		Encapsulatedtransport =>
			meitype: byte;
			data: array of byte;
		}
		
		read:	fn(fd: ref Sys->FD, msglim: int): ref TMmsg;
		packedsize:	fn(nil: self ref TMmsg): int;
		pack:	fn(nil: self ref TMmsg): array of byte;
		unpack:	fn(a: array of byte): (int, ref TMmsg);
		text:	fn(nil: self ref TMmsg): string;
		mtype:	fn(nil: self ref TMmsg): int;
	};

	RMmsg: adt {
		fcode: int;
		pick {
		Readerror =>
			error: string;					# tag is unused in this case
		Error =>
			data: byte;
		Readcoils =>
			count: int;
			data: array of byte;			# coil status
		Readdiscreteinputs =>
			count: int;
			data: array of byte;			# inputs
		Readholdingregisters =>
			count: int;
			data: array of byte;			# registers, N (of N/2 words)
		Readinputregisters =>
			count: int;
			data: array of byte;			# input registers, N (of N/2 words)
		Writecoil =>
			offset: int;
			value: int;
		Writeregister =>
			offset: int;
			value: int;
		Readexception =>
			data: byte;
		Diagnostics =>
			subf: int;						# 2 bytes, sub-function type
			data: int;
		Commeventcounter =>
			status: int;					# 2 bytes
			count: int;						# 2 bytes
		Commeventlog =>
			count: int;						# 1 byte
			status: int;					# 2 bytes
			ecount: int;					# 2 bytes
			mcount: int;					# 2 bytes
			data: array of byte;			# events: (N-6) * byte
		Writecoils =>
			offset: int;
			quantity: int;					# 2 bytes, 0x0001 to 0x07B0
		Writeregisters =>
			offset: int;
			quantity: int;
		Slaveid =>
			count: int;
			data: array of byte;			# device specific
		Readfilerecord =>
			count: int;						# 1 byte, 0x07 to 0xF5
			data: array of byte;
		Writefilerecord =>
			count: int;
			data: array of byte;
		Maskwriteregister =>
			offset: int;					# 2 bytes
			andmask: int;					# 2 bytes
			ormask: int;					# 2 bytes
		Rwregisters =>
			count: int;
			data: array of byte;
		Readfifo =>
			count: int;						# 2 bytes
			fcount: int;					# 2 bytes, ²31
			data:	array of byte;
		Encapsulatedtransport =>
			meitype: byte;
			data: array of byte;
		}
		
		read:	fn(fd: ref Sys->FD, msize: int): ref RMmsg;
		packedsize:	fn(nil: self ref RMmsg): int;
		pack:	fn(nil: self ref RMmsg): array of byte;
		unpack:	fn(a: array of byte): (int, ref RMmsg);
		text:	fn(nil: self ref RMmsg): string;
		mtype:	fn(nil: self ref RMmsg): int;
	};
	
	init:	fn();
	
	rtupack:	fn(addr: byte, pdu: array of byte): array of byte;
	rtuunpack:	fn(data: array of byte): (byte, array of byte, int, string);
	rtucrc:		fn(addr: byte, pdu: array of byte): int;
	rtucrc_test:		fn(addr: byte, pdu: array of byte): int;
};
