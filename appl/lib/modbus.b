implement Modbus;

include "sys.m";
include "string.m";
include "crc.m";

include "modbus.m";

sys: Sys;
str: String;
crc: Crc;
	CRCstate: import crc;

POLY: con int 16rA001;
SEED: con int 16r0001;

CR:	con byte 16r0D;
LF: con byte 16r0A;

crc_state: ref CRCstate;

error_types: array of int;

init()
{
	if(sys == nil)
		sys = load Sys Sys->PATH;
	if(str == nil)
		str = load String String->PATH;
	if(crc == nil) {
		crc = load Crc Crc->PATH;
		crc_state = crc->init(POLY, SEED);
	}
	
	error_types = array[] of {
		Terror + Treadcoils,
		Terror + Treaddiscreteinputs,
		Terror + Treadholdingregisters,
		Terror + Treadinputregisters,
		Terror + Twritecoil,
		Terror + Twriteregister,
		Terror + Treadexception,
		Terror + Tdiagnostics,
		Terror + Tcommeventcounter,
		Terror + Tcommeventlog,
		Terror + Twritecoils,
		Terror + Twriteregisters,
		Terror + Tslaveid,
		Terror + Treadfilerecord,
		Terror + Twritefilerecord,
		Terror + Tmaskwriteregister,
		Terror + Trwregisters,
		Terror + Treadfifo,
		Terror + Tencapsulatedtransport,
	};
	
#	tabs();
}

funciserror(f: int): int
{
	e := 0;
	for(i := 0; i < len error_types; i++)
		if(error_types[i] == f) {
			e = 1;
			break;
		}
	return e;
}

hexdump(b: array of byte): string
{
	s := "";
	for(i:=0; i<len b; i++) {
		if(i%8 == 0)
			s = s + "\n\t";
		s = sys->sprint("%s %02X", s, int(b[i]));
	}
	
	return str->drop(s, "\n");
}

tabs() {
	sys->print("crctab:");
	i := 0;
	while(i < len crc_state.crctab) {
		if(i % 8 == 0)
			sys->print("\n");
		sys->print(" %02X", crc_state.crctab[i]);
		i++;
	}
	sys->print("\n");

	tab := array[256] of int;
	for(i=0; i<256; i++) {
		mcrc := 0;
		c :=  i;
		for(j:=0; j<8; j++) {
			if((mcrc^c) & 1)
				mcrc = (mcrc >> 1) ^ int 16rA001;
			else
				mcrc = mcrc >> 1;
			c = c >> 1;
		}
		tab[i] = mcrc;
	}
	sys->print("modbus tab:");
	i = 0;
	while(i<len tab) {
		if(i % 8 == 0)
			sys->print("\n");
		sys->print(" %02X", int tab[i]);
		i++;
	}
}

p16(a: array of byte, o: int, v: int): int
{
	a[o] = byte (v>>8);
	a[o+1] = byte v;
	return o+BIT16SZ;
}

g16(f: array of byte, i: int): int
{
	return ((int f[i+1]) << 8) | int f[i];
}

swap(word: int): int
{
	msb := word >> 8;
	lsb := word % 256;
	return (lsb<<8) + msb;
}


crackheader(b: array of byte): int
{
	if(b == nil || len b < 5)
		return FrameUnknown;
	h := FrameUnknown;
	if(g16(b, 2) == 0)
		h = FrameTCP;					# high likelihood
	if(b[0] == byte ':' && h != FrameTCP)
		h = FrameASCII;					# moderate chance
	if(h == FrameUnknown)
		h = FrameRTU;					# punt
	return h;
}

# return address and new offset to next byte
address(b: array of byte, f: int): (int, int)
{
	if(len b <= headersize(f))
		return (-1, 0);
	addr := -1;
	o := 0;
	case f {
	FrameRTU =>
		addr = int b[0];
		o = 1;
	FrameASCII =>
		(addr, nil) = str->toint(string b[1:3], 16);
		o = 3;
	FrameTCP =>
		addr = int b[6];
		o = 7;
	}
	return (addr, o);
}

errorchecksize(f: int): int
{
	sz := 0;
	case f {
	FrameRTU => sz = BIT16SZ;
	FrameASCII => sz = BIT16SZ+BIT16SZ;
	}
	return sz;
}

# return function type and offset to next byte
functiontype(b: array of byte, h: int): (int, int)
{
	f := -1;
	if(b == nil || len b < 5)
		return (f, 0);
	
	o := 0;
	case h {
	FrameRTU =>
		f = int b[1];
		o = 2;
	FrameASCII =>
		(f, nil) = str->toint(string b[3:5], 16);
		o = 5;
	FrameTCP =>
		if(len b > 7) {
			f = int b[7];
			o = 8;
		}
	}
	
	return (f, o);
}

headersize(f: int): int
{
	sz := 0;
	case f {
	FrameRTU => sz = BIT8SZ;							# address
	FrameASCII => sz = BIT8SZ+BIT16SZ;					# :address
	FrameTCP => sz = BIT16SZ+BIT16SZ+BIT16SZ+BIT8SZ;	# ?? 00 address
	}
	return sz;
}

ttag2type := array[] of {
tagof TMmsg.Readerror => 0,
tagof TMmsg.Error => Terror,
tagof TMmsg.Readcoils => Treadcoils,
tagof TMmsg.Readdiscreteinputs => Treaddiscreteinputs,
tagof TMmsg.Readholdingregisters => Treadholdingregisters,
tagof TMmsg.Readinputregisters => Treadinputregisters,
tagof TMmsg.Writecoil => Twritecoil,
tagof TMmsg.Writeregister => Twriteregister,
tagof TMmsg.Readexception => Treadexception,
tagof TMmsg.Diagnostics => Tdiagnostics,
tagof TMmsg.Commeventcounter => Tcommeventcounter,
tagof TMmsg.Commeventlog => Tcommeventlog,
tagof TMmsg.Writecoils => Twritecoils,
tagof TMmsg.Writeregisters => Twriteregisters,
tagof TMmsg.Slaveid => Tslaveid,
tagof TMmsg.Readfilerecord => Treadfilerecord,
tagof TMmsg.Writefilerecord => Twritefilerecord,
tagof TMmsg.Maskwriteregister => Tmaskwriteregister,
tagof TMmsg.Rwregisters => Trwregisters,
tagof TMmsg.Readfifo => Treadfifo,
tagof TMmsg.Encapsulatedtransport => Tencapsulatedtransport,
};

TMmsg.mtype(t: self ref TMmsg): int
{
	return ttag2type[tagof t];
}

TMmsg.read(fd: ref Sys->FD, msglim: int): ref TMmsg
{
	(msg, err) := readmsg(fd, msglim);
	if(err != nil)
		return ref TMmsg.Readerror(FrameError, -1, -1, err);
	if(msg == nil)
		return nil;
	(nil, m) := TMmsg.unpack(msg, FrameUnknown);
	if(m == nil)
		return ref TMmsg.Readerror(FrameError, -1, -1, "bad Modbus message format");
	return m;
}

TMmsg.packedsize(t: self ref TMmsg): int
{
	mtype := ttag2type[tagof t];
	if(mtype <= 0)
		return 0;
	ml := headersize(t.frame);
	pick m := t {
	Error =>
		ml += BIT8SZ+BIT8SZ;
	Readcoils =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Readdiscreteinputs =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Readholdingregisters =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Readinputregisters =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Writecoil =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Writeregister =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Readexception =>
		ml += BIT8SZ;
	Diagnostics =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Commeventcounter =>
		ml += BIT8SZ;
	Commeventlog =>
		ml += BIT8SZ;
	Writecoils =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ+BIT8SZ+len m.data;
	Writeregisters =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ+BIT8SZ+len m.data;
	Slaveid =>
		ml += BIT8SZ;
	Readfilerecord =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	Writefilerecord =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	Maskwriteregister =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ;
	Rwregisters =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ+BIT16SZ+BIT8SZ+len m.data;
	Readfifo =>
		ml += BIT8SZ+BIT16SZ;
	Encapsulatedtransport =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	}
	ml += errorchecksize(t.frame);
	return ml;
}

TMmsg.pack(t: self ref TMmsg): array of byte
{
	if(t == nil)
		return nil;
	ds := t.packedsize();
	if(ds <= 0)
		return nil;
	d := array[ds] of { * => byte 0};
	o := 0;
	case t.frame {
	FrameRTU =>
		d[0] = byte t.addr;
		d[1] = byte ttag2type[tagof t];
		o = 2;
	FrameASCII =>
		d[0] = byte ':';
		s := array of byte sys->sprint("%2X", t.addr);
		d[1] = s[0];
		d[2] = s[1];
		s = array of byte sys->sprint("%2X", ttag2type[tagof t]);
		d[3] = s[0];
		d[4] = s[1];
		o = 5;
	FrameTCP =>
		p16(d, 4, ds - headersize(t.frame) + BIT8SZ);
		d[6] = byte t.addr;
		d[7] = byte ttag2type[tagof t];
		o = 8;
	* =>
		return nil;
	}
	pick m := t {
	Error =>
		d[o-BIT8SZ] = m.fcode;
		d[o] = m.ecode;
		o += BIT8SZ;
	Readcoils =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.quantity);
		o += BIT16SZ+BIT16SZ;
	Readdiscreteinputs =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.quantity);
		o += BIT16SZ+BIT16SZ;
	Readholdingregisters =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.quantity);
		o += BIT16SZ+BIT16SZ;
	Readinputregisters =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.quantity);
		o += BIT16SZ+BIT16SZ;
	Writecoil =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.value);
		o += BIT16SZ+BIT16SZ;
	Writeregister =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.value);
		o += BIT16SZ+BIT16SZ;
	Readexception =>
		;
	Diagnostics =>
		p16(d, o, m.subf);
		p16(d, o+BIT16SZ, m.data);
		o += BIT16SZ+BIT16SZ;
	Commeventcounter =>
		;
	Commeventlog =>
		;
	Writecoils =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.quantity);
		d[o+BIT16SZ+BIT16SZ] = byte m.count;
		d[o+BIT16SZ+BIT16SZ+BIT8SZ:] = m.data;
		o += BIT16SZ+BIT16SZ+BIT8SZ+m.count;
	Writeregisters =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.quantity);
		d[o+BIT16SZ+BIT16SZ] = byte m.count;
		d[o+BIT16SZ+BIT16SZ+BIT8SZ:] = m.data;
		o += BIT16SZ+BIT16SZ+BIT8SZ+m.count;
	Slaveid =>
		;
	Readfilerecord =>
		d[o] = byte m.count;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+m.count;
	Writefilerecord =>
		d[o] = byte m.count;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+m.count;
	Maskwriteregister =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.andmask);
		p16(d, o+BIT16SZ+BIT16SZ, m.ormask);
		o += BIT16SZ+BIT16SZ+BIT16SZ;
	Rwregisters =>
		p16(d, o, m.roffset);
		p16(d, o+BIT16SZ, m.rquantity);
		p16(d, o+BIT16SZ+BIT16SZ, m.woffset);
		p16(d, o+BIT16SZ+BIT16SZ+BIT16SZ, m.wquantity);
		d[o+BIT16SZ+BIT16SZ+BIT16SZ+BIT16SZ] = byte m.count;
		d[o+BIT16SZ+BIT16SZ+BIT16SZ+BIT16SZ+BIT8SZ:] = m.data;
		o += BIT16SZ+BIT16SZ+BIT16SZ+BIT16SZ+BIT8SZ+m.count;
	Readfifo =>
		p16(d, o, m.offset);
		o += BIT16SZ;
	Encapsulatedtransport =>
		d[o] = m.meitype;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+BIT8SZ;
	* =>
		return nil;
	}
	
	case t.frame {
	FrameRTU =>
		t.check = rtucrc(d[0:o]);
		d[ds-2] = byte(t.check);
		d[ds-1] = byte(t.check >> 8);
	FrameASCII =>
		t.check = asciilrc(d[1:ds-2]);
		s := array of byte sys->sprint("%2X", t.check);
		d[ds-2] = s[0];
		d[ds-1] = s[1];
	}
	
	return d;
}

TMmsg.unpack(b: array of byte, h: int): (int, ref TMmsg)
{
	n := len b;
	if(h == FrameUnknown)
		h = crackheader(b);
	if(h == FrameUnknown || n < headersize(h))
		return (0, nil);
	
	(addr, o) := address(b, h);
	if(addr == -1)
		return (o, ref TMmsg.Readerror(FrameError, addr, -1, "Invalid address"));

	(mtype, p) := functiontype(b, h);
	if(mtype == -1)
		return (0, nil);
	if((mtype >= Tmax || mtype < Treadcoils) && !funciserror(mtype))
		return (p, ref TMmsg.Readerror(FrameError, addr, -1, 
					sys->sprint("Invalid function (%0X)", mtype)));
	
	H := headersize(h);
	checksz := errorchecksize(h);
	o = p;
	m: ref TMmsg;
	case mtype {
	* =>
		sys->print("modbus: TMmsg.unpack: bad type %d\n", mtype);
		return (-1, nil);
	Treadcoils =>
		offset := g16(b, H);
		v := g16(b, H+BIT16SZ);
		m = ref TMmsg.Readcoils(h, addr, 0, offset, v);
		o += BIT16SZ+BIT16SZ;
	Treaddiscreteinputs =>
		offset := g16(b, H);
		v := g16(b, H+BIT16SZ);
		m = ref TMmsg.Readdiscreteinputs(h, addr, 0, offset, v);
		o += BIT16SZ+BIT16SZ;
	Treadholdingregisters =>
		offset := g16(b, H);
		v := g16(b, H+BIT16SZ);
		m = ref TMmsg.Readholdingregisters(h, addr, 0, offset, v);
		o += BIT16SZ+BIT16SZ;
	Treadinputregisters =>
		offset := g16(b, H);
		v := g16(b, H+BIT16SZ);
		m = ref TMmsg.Readinputregisters(h, addr, 0, offset, v);
		o += BIT16SZ+BIT16SZ;
	Twritecoil =>
		offset := g16(b, H);
		v := g16(b, H+BIT16SZ);
		m = ref TMmsg.Writecoil(h, addr, 0, offset, v);
		o += BIT16SZ+BIT16SZ;
	Twriteregister =>
		offset := g16(b, H);
		v := g16(b, H+BIT16SZ);
		m = ref TMmsg.Writeregister(h, addr, 0, offset, v);
		o += BIT16SZ+BIT16SZ;
	Treadexception =>
		m = ref TMmsg.Readexception(h, addr, 0, nil);
	Tdiagnostics =>
		st := g16(b, H);
		v := g16(b, H+BIT16SZ);
		m = ref TMmsg.Diagnostics(h, addr, 0, st, v);
		o += BIT16SZ+BIT16SZ;
	Tcommeventcounter =>
		m = ref TMmsg.Commeventcounter(h, addr, 0, nil);
	Tcommeventlog =>
		m = ref TMmsg.Commeventlog(h, addr, 0, nil);
	Twritecoils =>
		offset := g16(b, H);
		q := g16(b, H+BIT16SZ);
		c := int b[H+BIT16SZ+BIT16SZ];
		O := H+BIT16SZ+BIT16SZ+BIT8SZ;
		if(c <= n-O) {
			d := b[O:O+c];
			m = ref TMmsg.Writecoils(h, addr, 0, offset, q, c, d);
			o += BIT16SZ+BIT16SZ+BIT8SZ+c;
		}
	Twriteregisters =>
		offset := g16(b, H);
		q := g16(b, H+BIT16SZ);
		c := int b[H+BIT16SZ+BIT16SZ];
		O := H+BIT16SZ+BIT16SZ+BIT8SZ;
		if(c <= n-O) {
			d := b[O:O+c];
			m = ref TMmsg.Writeregisters(h, addr, 0, offset, q, c, d);
			o += BIT16SZ+BIT16SZ+BIT8SZ+c;
		}
	Tslaveid =>
		m = ref TMmsg.Slaveid(h, addr, 0, nil);
	Treadfilerecord =>
		c := int b[H];
		O := H+BIT8SZ;
		if(c <= n-O) {
			d := b[O:O+int c];
			m = ref TMmsg.Readfilerecord(h, addr, 0, c, d);
			o += BIT8SZ+c;
		}
	Twritefilerecord =>
		c := int b[H];
		O := H+BIT8SZ;
		if(c <= n-O){
			d := b[O:O+c];
			m = ref TMmsg.Writefilerecord(h, addr, 0, c, d);
			o += BIT8SZ+c;
		}
	Tmaskwriteregister =>
		offset := g16(b, H);
		amask := g16(b, H+BIT16SZ);
		omask := g16(b, H+BIT16SZ+BIT16SZ);
		m = ref TMmsg.Maskwriteregister(h, addr, 0, offset, amask, omask);
		o += BIT16SZ+BIT16SZ+BIT16SZ;
	Trwregisters =>
		ro := g16(b, H);
		qr := g16(b, H+BIT16SZ);
		wo := g16(b, H+BIT16SZ+BIT16SZ);
		qw := g16(b, H+BIT16SZ+BIT16SZ+BIT16SZ);
		c := int b[H+BIT16SZ+BIT16SZ+BIT16SZ+BIT16SZ];
		O := H+BIT16SZ+BIT16SZ+BIT16SZ+BIT16SZ;
		if(c <= n-O) {
			d := b[O:O+c];
			m = ref TMmsg.Rwregisters(h, addr, 0, ro, qr, wo, qw, c, d);
			o += BIT16SZ+BIT16SZ+BIT16SZ+BIT16SZ+c;
		}
	Treadfifo =>
		offset := g16(b, H);
		m = ref TMmsg.Readfifo(h, addr, 0, offset);
		o += BIT16SZ;
	Tencapsulatedtransport =>
		;		# not supported
	}
	if(m != nil && n < o+checksz) {
		case m.frame {
		FrameRTU =>
			m.check = g16(b, o);
			if(m.check != rtucrc(b[0:o]))
				m = ref TMmsg.Readerror(m.frame, addr, m.check, "Invalid CRC");
		FrameASCII =>
			(m.check, nil) = str->toint(string b[o:o+2], 16);
			if(m.check != asciilrc(b[1:o]))
				m = ref TMmsg.Readerror(m.frame, addr, m.check, "Invalid LRC");
			if(n < o+checksz+BIT16SZ ||
				(b[o+checksz] != CR && b[o+checksz+BIT8SZ] != LF))
				m = ref TMmsg.Readerror(m.frame, addr, m.check, "Incomplete frame");
		}
		o += checksz;
	} else
		m = nil;
	return (o, m);
}

tmsgname := array[] of {
tagof TMmsg.Readerror => "Read Error",
tagof TMmsg.Error => "Error",
tagof TMmsg.Readcoils => "Read Coils",
tagof TMmsg.Readdiscreteinputs => "Read Discrete Inputs",
tagof TMmsg.Readholdingregisters => "Read Holding Registers",
tagof TMmsg.Readinputregisters => "Read Input Registers",
tagof TMmsg.Writecoil => "Write Single Coil",
tagof TMmsg.Writeregister => "Write Single Register",
tagof TMmsg.Readexception => "Read Exception Status",
tagof TMmsg.Diagnostics => "Diagnostics",
tagof TMmsg.Commeventcounter => "Get Comm Event Counter",
tagof TMmsg.Commeventlog => "Get Comm Event Log",
tagof TMmsg.Writecoils => "Write Multiple Coils",
tagof TMmsg.Writeregisters => "Write Multiple Registers",
tagof TMmsg.Slaveid => "Report Slave ID",
tagof TMmsg.Readfilerecord => "Read File Record",
tagof TMmsg.Writefilerecord => "Write File Record",
tagof TMmsg.Maskwriteregister => "Mask Write Register",
tagof TMmsg.Rwregisters => "Read/Write Multiple Registers",
tagof TMmsg.Readfifo => "Read FIFO Queue",
tagof TMmsg.Encapsulatedtransport => "Encapsulated Interface Transport",
};

TMmsg.text(t: self ref TMmsg): string
{
	if(t == nil)
		return "(nil)";
	return "TMmsg "+tmsgname[tagof t];
}

rtag2type := array[] of {
tagof RMmsg.Readerror => 0,
tagof RMmsg.Error => Terror,
tagof RMmsg.Readcoils => Treadcoils,
tagof RMmsg.Readdiscreteinputs => Treaddiscreteinputs,
tagof RMmsg.Readholdingregisters => Treadholdingregisters,
tagof RMmsg.Readinputregisters => Treadinputregisters,
tagof RMmsg.Writecoil => Twritecoil,
tagof RMmsg.Writeregister => Twriteregister,
tagof RMmsg.Readexception => Treadexception,
tagof RMmsg.Diagnostics => Tdiagnostics,
tagof RMmsg.Commeventcounter => Tcommeventcounter,
tagof RMmsg.Commeventlog => Tcommeventlog,
tagof RMmsg.Writecoils => Twritecoils,
tagof RMmsg.Writeregisters => Twriteregisters,
tagof RMmsg.Slaveid => Tslaveid,
tagof RMmsg.Readfilerecord => Treadfilerecord,
tagof RMmsg.Writefilerecord => Twritefilerecord,
tagof RMmsg.Maskwriteregister => Tmaskwriteregister,
tagof RMmsg.Rwregisters => Trwregisters,
tagof RMmsg.Readfifo => Treadfifo,
tagof RMmsg.Encapsulatedtransport => Tencapsulatedtransport,
};

RMmsg.mtype(r: self ref RMmsg): int
{
	return rtag2type[tagof r];
}

RMmsg.read(fd: ref Sys->FD, msglim: int): ref RMmsg
{
	(msg, err) := readmsg(fd, msglim);
	if(err != nil)
		return ref RMmsg.Readerror(FrameError, -1, -1, err);
	if(msg == nil)
		return nil;
	(nil, m) := RMmsg.unpack(msg, FrameUnknown);
	if(m == nil)
		return ref RMmsg.Readerror(FrameError, -1, -1, "bad Modbus message format");
	return m;
}

RMmsg.packedsize(t: self ref RMmsg): int
{
	mtype := rtag2type[tagof t];
	if(mtype <= 0)
		return 0;
	ml := headersize(t.frame);
	pick m := t {
	Error =>
		ml += BIT8SZ+BIT8SZ;
	Readcoils =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	Readdiscreteinputs =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	Readholdingregisters =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	Readinputregisters =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	Writecoil =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Writeregister =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Readexception =>
		ml += BIT8SZ+BIT8SZ;
	Diagnostics =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Commeventcounter =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Commeventlog =>
		ml += BIT8SZ+BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ+len m.data;
	Writecoils =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Writeregisters =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ;
	Slaveid =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	Readfilerecord =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	Writefilerecord =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	Maskwriteregister =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ;
	Rwregisters =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	Readfifo =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ+len m.data;
	Encapsulatedtransport =>
		ml += BIT8SZ+BIT8SZ+len m.data;
	}
	ml += errorchecksize(t.frame);
	return ml;
}

RMmsg.pack(t: self ref RMmsg): array of byte
{
	if(t == nil)
		return nil;
	ds := t.packedsize();
	if(ds <= 0)
		return nil;
	d := array[ds] of { * => byte 0};
	o := 0;
	case t.frame {
	FrameRTU =>
		d[0] = byte t.addr;
		d[1] = byte rtag2type[tagof t];
		o = 2;
	FrameASCII =>
		d[0] = byte ':';
		s := array of byte sys->sprint("%2X", t.addr);
		d[1] = s[0];
		d[2] = s[1];
		s = array of byte sys->sprint("%2X", rtag2type[tagof t]);
		d[3] = s[0];
		d[4] = s[1];
		o = 5;
	FrameTCP =>
		p16(d, 4, ds - headersize(t.frame) + BIT8SZ);
		d[6] = byte t.addr;
		d[7] = byte rtag2type[tagof t];
		o = 8;
	* =>
		return nil;
	}
	pick m := t {
	Error =>
		d[o-BIT8SZ] = m.fcode;
		d[o] = m.ecode;
		o += BIT8SZ;
	Readcoils =>
		d[o] = byte m.count;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+m.count;
	Readdiscreteinputs =>
		d[o] = byte m.count;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+m.count;
	Readholdingregisters =>
		d[o] = byte m.count;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+m.count;
	Readinputregisters =>
		d[o] = byte m.count;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+m.count;
	Writecoil =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.value);
		o += BIT16SZ+BIT16SZ;
	Writeregister =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.value);
		o += BIT16SZ+BIT16SZ;
	Readexception =>
		d[o] = m.data;
		o += BIT8SZ;
	Diagnostics =>
		p16(d, o, m.subf);
		p16(d, o+BIT16SZ, m.data);
		o += BIT16SZ+BIT16SZ;
	Commeventcounter =>
		p16(d, o, m.status);
		p16(d, o, m.count);
		o += BIT16SZ+BIT16SZ;
	Commeventlog =>
		d[o] = byte m.count;
		p16(d, o+BIT8SZ, m.status);
		p16(d, o+BIT8SZ+BIT16SZ, m.ecount);
		p16(d, o+BIT8SZ+BIT16SZ+BIT16SZ, m.mcount);
		d[o+BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ:] = m.data;
		o += BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ+len m.data;
	Writecoils =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.quantity);
		o += BIT16SZ+BIT16SZ;
	Writeregisters =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.quantity);
		o += BIT16SZ+BIT16SZ;
	Slaveid =>
		d[o] = byte m.count;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+m.count;
	Readfilerecord =>
		d[o] = byte m.count;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+m.count;
	Writefilerecord =>
		d[o] = byte m.count;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+m.count;
	Maskwriteregister =>
		p16(d, o, m.offset);
		p16(d, o+BIT16SZ, m.andmask);
		p16(d, o+BIT16SZ+BIT16SZ, m.ormask);
		o += BIT16SZ+BIT16SZ+BIT16SZ;
	Rwregisters =>
		d[o] = byte m.count;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+m.count;
	Readfifo =>
		p16(d, o, m.count);
		p16(d, o+BIT16SZ, m.fcount);
		d[o+BIT16SZ+BIT16SZ:] = m.data;
		o += BIT16SZ+BIT16SZ+len m.data;
	Encapsulatedtransport =>
		d[o] = m.meitype;
		d[o+BIT8SZ:] = m.data;
		o += BIT8SZ+len m.data;
	* =>
		return nil;
	}
	case t.frame {
	FrameRTU =>
		t.check = rtucrc(d[0:o]);
		d[ds-2] = byte(t.check);
		d[ds-1] = byte(t.check >> 8);
	FrameASCII =>
		t.check = asciilrc(d[1:ds-2]);
		s := array of byte sys->sprint("%2X", t.check);
		d[ds-2] = s[0];
		d[ds-1] = s[1];
	}
	return d;
}

RMmsg.unpack(b: array of byte, h: int): (int, ref RMmsg)
{
	n := len b;
	if(h == FrameUnknown)
		h = crackheader(b);
	if(h == FrameUnknown || n < headersize(h))
		return (0, nil);

	mtype := 0;
	addr := 0;
	o := 0;
	
	(addr, o) = address(b, h);
	if(addr == -1)
		return (o, ref RMmsg.Readerror(FrameError, addr, -1, "Invalid address"));

	(mtype, o) = functiontype(b, h);
	if(mtype == -1)
		return (0, nil);
	if((mtype >= Tmax || mtype < Treadcoils) && !funciserror(mtype))
		return (o, ref RMmsg.Readerror(FrameError, addr, -1,
					sys->sprint("Invalid function (%0X)", mtype)));

	if(n < o)
		return (0, nil);
	
	checksz := errorchecksize(h);
	m: ref RMmsg;
	case mtype {
	* =>
		if(funciserror(mtype)) {
			sys->fprint(sys->fildes(2), "%s\n", hexdump(b));
			if(n < o+BIT8SZ)
				break;
			m = ref RMmsg.Error(h, addr, 0, byte mtype, b[o]);
			o += BIT8SZ;
		} else
			return (o, ref RMmsg.Readerror(FrameError, addr, -1,
					sys->sprint("modbus: RMmsg.unpack: bad type %d\n", mtype)));
	Treadcoils =>
		c := int b[o];
		o += BIT8SZ;
		if(c == n - o) {
			d := b[o:o+c];
			m = ref RMmsg.Readcoils(h, addr, 0, c, d);
			o += len d;
		}
	Treaddiscreteinputs =>
		c := int b[o];
		o += BIT8SZ;
		if(c <= n - o) {
			d := b[o:o+c];
			m = ref RMmsg.Readdiscreteinputs(h, addr, 0, c, d);
			o += len d;
		}
	Treadholdingregisters =>
		c := int b[o];
		o += BIT8SZ;
		if(c <= n - o) {
			d := b[o:o+c];
			m = ref RMmsg.Readholdingregisters(h, addr, 0, c, d);
			o += len d;
		}
	Treadinputregisters =>
		c := int b[o];
		o += BIT8SZ;
		if(c <= n - o) {
			d := b[o:o+c];
			m = ref RMmsg.Readinputregisters(h, addr, 0, c, d);
			o += len d;
		}
	Twritecoil =>
		offset := g16(b, o);
		v := g16(b, o+BIT16SZ);
		m = ref RMmsg.Writecoil(h, addr, 0, offset, v);
		o += BIT16SZ+BIT16SZ;
	Twriteregister =>
		offset := g16(b, o);
		v := g16(b, o+BIT16SZ);
		m = ref RMmsg.Writeregister(h, addr, 0, offset, v);
		o += BIT16SZ+BIT16SZ;
	Treadexception =>
		d := b[o];
		m = ref RMmsg.Readexception(h, addr, 0, d);
		o += BIT8SZ;
	Tdiagnostics =>
		st := g16(b, o);
		v := g16(b, o+BIT16SZ);
		m = ref RMmsg.Diagnostics(h, addr, 0, st, v);
		o += BIT16SZ+BIT16SZ;
	Tcommeventcounter =>
		st := g16(b, o);
		c := g16(b, o+BIT16SZ);
		m = ref RMmsg.Commeventcounter(h, addr, 0, st, c);
		o += BIT16SZ+BIT16SZ;
	Tcommeventlog =>
		c := int b[o];
		o += BIT8SZ;
		if(c <= n - o) {
			st := g16(b, o);
			ec := g16(b, o+BIT16SZ);
			mc := g16(b, o+BIT16SZ+BIT16SZ);
			d := b[o:o+c];
			m = ref RMmsg.Commeventlog(h, addr, 0, c, st, ec, mc, d);
			o += BIT16SZ+BIT16SZ+BIT16SZ+c;
		}
	Twritecoils =>
		offset := g16(b, o);
		q := g16(b, o+BIT16SZ);
		m = ref RMmsg.Writecoils(h, addr, 0, offset, q);
		o += BIT16SZ+BIT16SZ;
	Twriteregisters =>
		offset := g16(b, o);
		q := g16(b, o+BIT16SZ);
		m = ref RMmsg.Writeregisters(h, addr, 0, offset, q);
		o += BIT16SZ+BIT16SZ;
	Tslaveid =>
		c := int b[o];
		o += BIT8SZ;
		if(c <= n - o) {
			d := b[o:o+c];
			m = ref RMmsg.Slaveid(h, addr, 0, c, d);
			o += c;
		}
	Treadfilerecord =>
		c := int b[o];
		o += BIT8SZ;
		if(c <= n - o) {
			d := b[o:o+c];
			m = ref RMmsg.Readfilerecord(h, addr, 0, c, d);
			o += c;
		}
	Twritefilerecord =>
		c := int b[o];
		o += BIT8SZ;
		if(c <= n - o) {
			d := b[o:o+c];
			m = ref RMmsg.Writefilerecord(h, addr, 0, c, d);
			o += c;
		}
	Tmaskwriteregister =>
		offset := g16(b, o);
		amask := g16(b, o+BIT16SZ);
		omask := g16(b, o+BIT16SZ+BIT16SZ);
		m = ref RMmsg.Maskwriteregister(h, addr, 0, offset, amask, omask);
		o += BIT16SZ+BIT16SZ+BIT16SZ;
	Trwregisters =>
		c := int b[o];
		o += BIT8SZ;
		if(c <= n - o) {
			d := b[o:o+c];
			m = ref RMmsg.Rwregisters(h, addr, 0, c, d);
			o += c;
		}
	Treadfifo =>
		c := g16(b, o);
		fc := g16(b, o+BIT16SZ);
		o += BIT16SZ+BIT16SZ;
		if(c <= n - o) {
			d := b[o:o+c];
			m = ref RMmsg.Readfifo(h, addr, 0, c, fc, d);
			o += c;
		}
	Tencapsulatedtransport =>
		;		# not supported
	}
	if(m != nil && n <= o+checksz) {
		case m.frame {
		FrameRTU =>
			m.check = g16(b, o);
			if(m.check != rtucrc(b[0:o]))
				m = ref RMmsg.Readerror(m.frame, addr, m.check, "Invalid CRC");
		FrameASCII =>
			(m.check, nil) = str->toint(string b[o:o+2], 16);
			if(m.check != asciilrc(b[1:o]))
				m = ref RMmsg.Readerror(m.frame, addr, m.check, "Invalid LRC");
			if(n < o+checksz+BIT16SZ ||
				(b[o+checksz] != CR && b[o+checksz+BIT8SZ] != LF))
				m = ref RMmsg.Readerror(m.frame, addr, m.check, "Incomplete frame");
		}
		o += checksz;
	} else
		m = nil;
	
	return (o, m);
}

rmsgname := array[] of {
tagof RMmsg.Readerror => "Read Error",
tagof RMmsg.Readcoils => "Read Coils",
tagof RMmsg.Readdiscreteinputs => "Read Discrete Inputs",
tagof RMmsg.Readholdingregisters => "Read Holding Registers",
tagof RMmsg.Readinputregisters => "Read Input Registers",
tagof RMmsg.Writecoil => "Write Single Coil",
tagof RMmsg.Writeregister => "Write Single Register",
tagof RMmsg.Readexception => "Read Exception Status",
tagof RMmsg.Diagnostics => "Diagnostics",
tagof RMmsg.Commeventcounter => "Get Comm Event Counter",
tagof RMmsg.Commeventlog => "Get Comm Event Log",
tagof RMmsg.Writecoils => "Write Multiple Coils",
tagof RMmsg.Writeregisters => "Write Multiple Registers",
tagof RMmsg.Slaveid => "Report Slave ID",
tagof RMmsg.Readfilerecord => "Read File Record",
tagof RMmsg.Writefilerecord => "Write File Record",
tagof RMmsg.Maskwriteregister => "Mask Write Register",
tagof RMmsg.Rwregisters => "Read/Write Multiple Registers",
tagof RMmsg.Readfifo => "Read FIFO Queue",
tagof RMmsg.Encapsulatedtransport => "Encapsulated Interface Transport",
};

RMmsg.text(t: self ref RMmsg): string
{
	if(t == nil)
		return "(nil)";
	return "RMmsg."+rmsgname[tagof t];
}

readmsg(nil: ref Sys->FD, nil: int): (array of byte, string)
{
	sys->werrstr("readmsg unimplemented");
	return (nil, sys->sprint("%r"));
}

asciilrc(b: array of byte): int
{
	r := byte 0;
	n := len b;
	if(n > 0)
		r = b[0];
	
	for(i := 1; i < n; i++)
		r ^= b[i];
	
	return int r;
}

rtucrc(b: array of byte): int
{
	crc_state.crc = 16rFFFF;
	return crc16(crc_state, b, len b);
}

crc16(crcs : ref CRCstate, buf : array of byte, nb : int) : int
{
	n := nb;
	if (n > len buf)
		n = len buf;
	c := crcs.crc;
	tab := crcs.crctab;
	for (i := 0; i < n; i++) {
		c = (c >> 8) ^ tab[int(byte c ^ buf[i])];
	}
	crcs.crc = c;
	return c;
}

rtucrc_test(addr: byte, pdu: array of byte): int
{
	data := array[len pdu + 1] of byte;
	crc_ := 16rFFFF;
	
	data[0] = addr;
	data[1:] = pdu[0:];
	
	for(i:=0; i<len data; i++) {
		crc_ = crc_ ^ int data[i];
		for(j:=0; j<8; j++) {
			tmp := crc_ & 1;
			crc_ = crc_ >> 1;
			if(tmp)
				crc_ = crc_ ^ 16rA001;
		}
	}
	
	return crc_;
}
