implement Modbus;

include "sys.m";
include "crc.m";

include "modbus.m";

sys: Sys;
crc: Crc;
	CRCstate: import crc;

H: con BIT8SZ;		# minimum PDU header length: fcode[1]
OFFSET: con BIT16SZ;

POLY: con 16rA001;
SEED: con 16rFFFF;

init()
{
	if(sys == nil)
		sys = load Sys Sys->PATH;
	if(crc == nil) {
		crc = load Crc Crc->PATH;
	}
}

p16(a: array of byte, o: int, v: int): int
{
	a[o] = byte v;
	a[o+1] = byte (v>>8);
	return o+BIT16SZ;
}

g16(f: array of byte, i: int): int
{
	return ((int f[i+1]) << 8) | int f[i];
}

ttag2type := array[] of {
tagof TMmsg.Readerror => 0,
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
		return ref TMmsg.Readerror(0, err);
	if(msg == nil)
		return nil;
	(nil, m) := TMmsg.unpack(msg);
	if(m == nil)
		return ref TMmsg.Readerror(0, "bad Modbus message format");
	return m;
}

TMmsg.packedsize(t: self ref TMmsg): int
{
	mtype := ttag2type[tagof t];
	if(mtype <= 0)
		return 0;
	ml := H;
	pick m := t {
	Readcoils =>
		ml += OFFSET+BIT16SZ;
	Readdiscreteinputs =>
		ml += OFFSET+BIT16SZ;
	Readholdingregisters =>
		ml += OFFSET+BIT16SZ;
	Readinputregisters =>
		ml += OFFSET+BIT16SZ;
	Writecoil =>
		ml += OFFSET+BIT16SZ;
	Writeregister =>
		ml += OFFSET+BIT16SZ;
	Readexception =>
		;
	Diagnostics =>
		ml += BIT16SZ+BIT16SZ;
	Commeventcounter =>
		;
	Commeventlog =>
		;
	Writecoils =>
		ml += OFFSET+BIT16SZ+BIT8SZ+len m.data;
	Writeregisters =>
		ml += OFFSET+BIT16SZ+BIT8SZ+len m.data;
	Slaveid =>
		;
	Readfilerecord =>
		ml += BIT8SZ+len m.data;
	Writefilerecord =>
		ml += BIT8SZ+len m.data;
	Maskwriteregister =>
		ml += OFFSET+BIT16SZ+BIT16SZ;
	Rwregisters =>
		ml += OFFSET+BIT16SZ+BIT16SZ+BIT16SZ+BIT8SZ+len m.data;
	Readfifo =>
		ml += OFFSET;
	Encapsulatedtransport =>
		ml += BIT8SZ+len m.data;
	}
	return ml;
}

TMmsg.pack(t: self ref TMmsg): array of byte
{
	if(t == nil)
		return nil;
	ds := t.packedsize();
	if(ds <= 0)
		return nil;
	d := array[ds] of byte;
	d[0] = byte ttag2type[tagof t];
	pick m := t {
	Readcoils =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.quantity);
	Readdiscreteinputs =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.quantity);
	Readholdingregisters =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.quantity);
	Readinputregisters =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.quantity);
	Writecoil =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.value);
	Writeregister =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.value);
	Readexception =>
		;
	Diagnostics =>
		p16(d, H, m.subf);
		p16(d, H+BIT16SZ, m.data);
	Commeventcounter =>
		;
	Commeventlog =>
		;
	Writecoils =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.quantity);
		d[H+OFFSET+BIT16SZ] = byte m.count;
		d[H+OFFSET+BIT16SZ+BIT8SZ:] = m.data;
	Writeregisters =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.quantity);
		d[H+OFFSET+BIT16SZ] = byte m.count;
		d[H+OFFSET+BIT16SZ+BIT8SZ:] = m.data;
	Slaveid =>
		;
	Readfilerecord =>
		d[H] = byte m.count;
		d[H+BIT8SZ:] = m.data;
	Writefilerecord =>
		d[H] = byte m.count;
		d[H+BIT8SZ:] = m.data;
	Maskwriteregister =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.andmask);
		p16(d, H+OFFSET+BIT16SZ, m.ormask);
	Rwregisters =>
		p16(d, H, m.roffset);
		p16(d, H+OFFSET, m.rquantity);
		p16(d, H+OFFSET+BIT16SZ, m.woffset);
		p16(d, H+OFFSET+BIT16SZ+OFFSET, m.wquantity);
		d[H+OFFSET+BIT16SZ+OFFSET+BIT16SZ] = byte m.count;
		d[H+OFFSET+BIT16SZ+OFFSET+BIT16SZ+BIT8SZ:] = m.data;
	Readfifo =>
		p16(d, H, m.offset);
	Encapsulatedtransport =>
		d[H] = m.meitype;
		d[H+BIT8SZ:] = m.data;
	* =>
		return nil;
	}
	return d;
}

TMmsg.unpack(f: array of byte): (int, ref TMmsg)
{
	if(len f < H)
		return (0, nil);
	mtype := int f[0];
	if(mtype >= Tmax || mtype < Treadcoils)
		return (-1, nil);
	
	size := H;
	m: ref TMmsg;
	case mtype {
	Treadcoils =>
		offset := g16(f, H);
		v := g16(f, H+OFFSET);
		m = ref TMmsg.Readcoils(mtype, offset, v);
		size += OFFSET+BIT16SZ;
	Treaddiscreteinputs =>
		offset := g16(f, H);
		v := g16(f, H+OFFSET);
		m = ref TMmsg.Readdiscreteinputs(mtype, offset, v);
		size += OFFSET+BIT16SZ;
	Treadholdingregisters =>
		offset := g16(f, H);
		v := g16(f, H+OFFSET);
		m = ref TMmsg.Readholdingregisters(mtype, offset, v);
		size += OFFSET+BIT16SZ;
	Treadinputregisters =>
		offset := g16(f, H);
		v := g16(f, H+OFFSET);
		m = ref TMmsg.Readinputregisters(mtype, offset, v);
		size += OFFSET+BIT16SZ;
	Twritecoil =>
		offset := g16(f, H);
		v := g16(f, H+OFFSET);
		m = ref TMmsg.Writecoil(mtype, offset, v);
		size += OFFSET+BIT16SZ;
	Twriteregister =>
		offset := g16(f, H);
		v := g16(f, H+OFFSET);
		m = ref TMmsg.Writeregister(mtype, offset, v);
		size += OFFSET+BIT16SZ;
	Treadexception =>
		m = ref TMmsg.Readexception(mtype, nil);
	Tdiagnostics =>
		st := g16(f, H);
		v := g16(f, H+OFFSET);
		m = ref TMmsg.Diagnostics(mtype, st, v);
		size += OFFSET+BIT16SZ;
	Tcommeventcounter =>
		m = ref TMmsg.Commeventcounter(mtype, nil);
	Tcommeventlog =>
		m = ref TMmsg.Commeventlog(mtype, nil);
	Twritecoils =>
		offset := g16(f, H);
		q := g16(f, H+OFFSET);
		c := int f[H+OFFSET+BIT16SZ];
		O : con H+OFFSET+BIT16SZ+BIT8SZ;
		if(c <= len f-O) {
			d := f[O:O+c];
			m = ref TMmsg.Writecoils(mtype, offset, q, c, d);
			size = O+c;
		}
	Twriteregisters =>
		offset := g16(f, H);
		q := g16(f, H+OFFSET);
		c := int f[H+OFFSET+BIT16SZ];
		O : con H+OFFSET+BIT16SZ+BIT8SZ;
		if(c <= len f-O) {
			d := f[O:O+c];
			m = ref TMmsg.Writeregisters(mtype, offset, q, c, d);
			size = O+c;
		}
	Tslaveid =>
		m = ref TMmsg.Slaveid(mtype, nil);
	Treadfilerecord =>
		c := int f[H];
		O : con H+BIT8SZ;
		if(c <= len f-O) {
			d := f[O:O+int c];
			m = ref TMmsg.Readfilerecord(mtype, c, d);
			size = O+c;
		}
	Twritefilerecord =>
		c := int f[H];
		O : con H+BIT8SZ;
		if(c <= len f-O){
			d := f[O:O+c];
			m = ref TMmsg.Writefilerecord(mtype, c, d);
			size = O+c;
		}
	Tmaskwriteregister =>
		offset := g16(f, H);
		amask := g16(f, H+OFFSET);
		omask := g16(f, H+OFFSET+BIT16SZ);
		m = ref TMmsg.Maskwriteregister(mtype, offset, amask, omask);
		size += OFFSET+BIT16SZ+BIT16SZ;
	Trwregisters =>
		ro := g16(f, H);
		qr := g16(f, H+OFFSET);
		wo := g16(f, H+OFFSET+BIT16SZ);
		qw := g16(f, H+OFFSET+BIT16SZ+OFFSET);
		c := int f[H+OFFSET+BIT16SZ+OFFSET+BIT16SZ];
		O : con H+OFFSET+BIT16SZ+OFFSET+BIT16SZ;
		if(c <= len f-O) {
			d := f[O:O+c];
			m = ref TMmsg.Rwregisters(mtype, ro, qr, wo, qw, c, d);
			size = O+c;
		}
	Treadfifo =>
		o := g16(f, H);
		m = ref TMmsg.Readfifo(mtype, o);
		size += OFFSET;
	Tencapsulatedtransport =>
		;		# not supported
	* =>
		sys->werrstr("unrecognised mtype " + string mtype);
		return (-1, nil);
	}
	if(m == nil) {
		sys->werrstr("bad message size");
		return (-1, nil);
	}
	return (size, m);
}

tmsgname := array[] of {
tagof TMmsg.Readerror => "Readerror",
tagof TMmsg.Readcoils => "Readcoils",
tagof TMmsg.Readdiscreteinputs => "Readdiscreteinputs",
tagof TMmsg.Readholdingregisters => "Readholdingregisters",
tagof TMmsg.Readinputregisters => "Readinputregisters",
tagof TMmsg.Writecoil => "Writecoil",
tagof TMmsg.Writeregister => "Writeregister",
tagof TMmsg.Readexception => "Readexception",
tagof TMmsg.Diagnostics => "Diagnostics",
tagof TMmsg.Commeventcounter => "Commeventcounter",
tagof TMmsg.Commeventlog => "Commeventlog",
tagof TMmsg.Writecoils => "Writecoils",
tagof TMmsg.Writeregisters => "Writeregisters",
tagof TMmsg.Slaveid => "Slaveid",
tagof TMmsg.Readfilerecord => "Readfilerecord",
tagof TMmsg.Writefilerecord => "Writefilerecord",
tagof TMmsg.Maskwriteregister => "Maskwriteregister",
tagof TMmsg.Rwregisters => "Rwregisters",
tagof TMmsg.Readfifo => "Readfifo",
tagof TMmsg.Encapsulatedtransport => "Encapsulatedtransport",
};

TMmsg.text(t: self ref TMmsg): string
{
	if(t == nil)
		return "(nil)";
	s := sys->sprint("TMmsg.%s(%d", tmsgname[tagof t], t.fcode);
	return s+")";
}

rtag2type := array[] of {
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
		return ref RMmsg.Readerror(0, err);
	if(msg == nil)
		return nil;
	(nil, m) := RMmsg.unpack(msg);
	if(m == nil)
		return ref RMmsg.Readerror(0, "bad ModbusP R-message format");
	return m;
}

RMmsg.packedsize(t: self ref RMmsg): int
{
	mtype := rtag2type[tagof t];
	if(mtype <= 0)
		return 0;
	ml := H;
	pick m := t {
	Readcoils =>
		ml += BIT8SZ+len m.data;
	Readdiscreteinputs =>
		ml += BIT8SZ+len m.data;
	Readholdingregisters =>
		ml += BIT8SZ+len m.data;
	Readinputregisters =>
		ml += BIT8SZ+len m.data;
	Writecoil =>
		ml += OFFSET+BIT16SZ;
	Writeregister =>
		ml += OFFSET+BIT16SZ;
	Readexception =>
		ml += BIT8SZ;
	Diagnostics =>
		ml += BIT16SZ+BIT16SZ;
	Commeventcounter =>
		ml += BIT16SZ+BIT16SZ;
	Commeventlog =>
		ml += BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ+len m.data;
	Writecoils =>
		ml += OFFSET+BIT16SZ;
	Writeregisters =>
		ml += OFFSET+BIT16SZ;
	Slaveid =>
		ml += BIT8SZ+len m.data;
	Readfilerecord =>
		ml += BIT8SZ+len m.data;
	Writefilerecord =>
		ml += BIT8SZ+len m.data;
	Maskwriteregister =>
		ml += OFFSET+BIT16SZ+BIT16SZ;
	Rwregisters =>
		ml += BIT8SZ+len m.data;
	Readfifo =>
		ml += BIT16SZ+BIT16SZ+len m.data;
	Encapsulatedtransport =>
		ml += BIT8SZ+len m.data;
	}
	return ml;
}

RMmsg.pack(t: self ref RMmsg): array of byte
{
	if(t == nil)
		return nil;
	ds := t.packedsize();
	if(ds <= 0)
		return nil;
	d := array[ds] of byte;
	d[0] = byte rtag2type[tagof t];
	pick m := t {
	Readcoils =>
		d[H] = byte m.count;
		d[H+BIT8SZ:] = m.data;
	Readdiscreteinputs =>
		d[H] = byte m.count;
		d[H+BIT8SZ:] = m.data;
	Readholdingregisters =>
		d[H] = byte m.count;
		d[H+BIT8SZ:] = m.data;
	Readinputregisters =>
		d[H] = byte m.count;
		d[H+BIT8SZ:] = m.data;
	Writecoil =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.value);
	Writeregister =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.value);
	Readexception =>
		d[H] = m.data;
	Diagnostics =>
		p16(d, H, m.subf);
		p16(d, H+BIT16SZ, m.data);
	Commeventcounter =>
		p16(d, H, m.status);
		p16(d, H, m.count);
	Commeventlog =>
		d[H] = byte m.count;
		p16(d, H+BIT8SZ, m.status);
		p16(d, H+BIT8SZ+BIT16SZ, m.ecount);
		p16(d, H+BIT8SZ+BIT16SZ+BIT16SZ, m.mcount);
		d[H+BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ:] = m.data;
	Writecoils =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.quantity);
	Writeregisters =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.quantity);
	Slaveid =>
		d[H] = byte m.count;
		d[H+BIT8SZ:] = m.data;
	Readfilerecord =>
		d[H] = byte m.count;
		d[H+BIT8SZ:] = m.data;
	Writefilerecord =>
		d[H] = byte m.count;
		d[H+BIT8SZ:] = m.data;
	Maskwriteregister =>
		p16(d, H, m.offset);
		p16(d, H+OFFSET, m.andmask);
		p16(d, H+OFFSET+BIT16SZ, m.ormask);
	Rwregisters =>
		d[H] = byte m.count;
		d[H+BIT8SZ:] = m.data;
	Readfifo =>
		p16(d, H, m.count);
		p16(d, H+BIT16SZ, m.fcount);
		d[H+BIT16SZ+BIT16SZ:] = m.data;
	Encapsulatedtransport =>
		d[H] = m.meitype;
		d[H+BIT8SZ:] = m.data;
	* =>
		return nil;
	}
	return d;
}

RMmsg.unpack(f: array of byte): (int, ref RMmsg)
{
	if(len f < H)
		return (0, nil);
	mtype := int f[0];
	if(mtype >= Tmax || mtype < Treadcoils)
		return (-1, nil);
	
	size := H;
	m: ref RMmsg;
	case mtype {
	Treadcoils =>
		c := int f[H];
		size += BIT8SZ;
		O : con H+BIT8SZ;
		if(c == len f-O) {
			d := f[O:O+c];
			m = ref RMmsg.Readcoils(mtype, c, d);
			size += len d;
		}
	Treaddiscreteinputs =>
		c := int f[H];
		size += BIT8SZ;
		O : con H+BIT8SZ;
		if(c == len f-O) {
			d := f[O:O+c];
			m = ref RMmsg.Readdiscreteinputs(mtype, c, d);
			size += len d;
		}
	Treadholdingregisters =>
		c := int f[H];
		size += BIT8SZ;
		O : con H+BIT8SZ;
		if(c == len f-O) {
			d := f[O:O+c];
			m = ref RMmsg.Readholdingregisters(mtype, c, d);
			size += len d;
		}
	Treadinputregisters =>
		c := int f[H];
		size += BIT8SZ;
		O : con H+BIT8SZ;
		if(c == len f-O) {
			d := f[O:O+c];
			m = ref RMmsg.Readinputregisters(mtype, c, d);
			size += len d;
		}
	Twritecoil =>
		offset := g16(f, H);
		v := g16(f, H+OFFSET);
		m = ref RMmsg.Writecoil(mtype, offset, v);
		size += OFFSET+BIT16SZ;
	Twriteregister =>
		offset := g16(f, H);
		v := g16(f, H+OFFSET);
		m = ref RMmsg.Writeregister(mtype, offset, v);
		size += OFFSET+BIT16SZ;
	Treadexception =>
		d := f[H];
		size += BIT8SZ;
		m = ref RMmsg.Readexception(mtype, d);
	Tdiagnostics =>
		st := g16(f, H);
		v := g16(f, H+OFFSET);
		m = ref RMmsg.Diagnostics(mtype, st, v);
		size += OFFSET+BIT16SZ;
	Tcommeventcounter =>
		st := g16(f, H);
		c := g16(f, H+OFFSET);
		m = ref RMmsg.Commeventcounter(mtype, st, c);
		size += OFFSET+BIT16SZ;
	Tcommeventlog =>
		c := int f[H];
		st := g16(f, H+BIT8SZ);
		ec := g16(f, H+BIT8SZ+BIT16SZ);
		mc := g16(f, H+BIT8SZ+BIT16SZ+BIT16SZ);
		size += BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ;
		O : con H+BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ;
		if(c <= len f-O) {
			d := f[O:O+c];
			m = ref RMmsg.Commeventlog(mtype, c, st, ec, mc, d);
			size += c;
		}
	Twritecoils =>
		offset := g16(f, H);
		q := g16(f, H+OFFSET);
		m = ref RMmsg.Writecoils(mtype, offset, q);
		size += OFFSET+BIT16SZ;
	Twriteregisters =>
		offset := g16(f, H);
		q := g16(f, H+OFFSET);
		m = ref RMmsg.Writeregisters(mtype, offset, q);
		size += OFFSET+BIT16SZ;
	Tslaveid =>
		c := int f[H];
		size += BIT8SZ;
		O : con H+BIT8SZ;
		if(c <= len f-O) {
			d := f[O:O+c];
			m = ref RMmsg.Slaveid(mtype, c, d);
			size += c;
		}
	Treadfilerecord =>
		c := int f[H];
		size += BIT8SZ;
		O : con H+BIT8SZ;
		if(c <= len f-O) {
			d := f[O:O+c];
			m = ref RMmsg.Readfilerecord(mtype, c, d);
			size += c;
		}
	Twritefilerecord =>
		c := int f[H];
		size += BIT8SZ;
		O : con H+BIT8SZ;
		if(c <= len f-O) {
			d := f[O:O+c];
			m = ref RMmsg.Writefilerecord(mtype, c, d);
			size += c;
		}
	Tmaskwriteregister =>
		offset := g16(f, H);
		amask := g16(f, H+OFFSET);
		omask := g16(f, H+OFFSET+BIT16SZ);
		m = ref RMmsg.Maskwriteregister(mtype, offset, amask, omask);
		size += OFFSET+BIT16SZ+BIT16SZ;
	Trwregisters =>
		c := int f[H];
		size += BIT8SZ;
		O : con H+BIT8SZ;
		if(c <= len f-O) {
			d := f[O:O+c];
			m = ref RMmsg.Rwregisters(mtype, c, d);
			size += c;
		}
	Treadfifo =>
		c := g16(f, H);
		fc := g16(f, H+BIT16SZ);
		size += BIT16SZ+BIT16SZ;
		O : con H+BIT16SZ+BIT16SZ;
		if(c <= len f-O) {
			d := f[O:O+c];
			m = ref RMmsg.Readfifo(mtype, c, fc, d);
			size += c;
		}
	Tencapsulatedtransport =>
		;		# not supported
	* =>
		sys->werrstr("unrecognised mtype " + string mtype);
		return (-1, nil);
	}
	if(m == nil) {
		sys->werrstr("bad message size");
		return (-1, nil);
	}
	return (size, m);
}

rmsgname := array[] of {
tagof RMmsg.Readerror => "Readerror",
tagof RMmsg.Readcoils => "Readcoils",
tagof RMmsg.Readdiscreteinputs => "Readdiscreteinputs",
tagof RMmsg.Readholdingregisters => "Readholdingregisters",
tagof RMmsg.Readinputregisters => "Readinputregisters",
tagof RMmsg.Writecoil => "Writecoil",
tagof RMmsg.Writeregister => "Writeregister",
tagof RMmsg.Readexception => "Readexception",
tagof RMmsg.Diagnostics => "Diagnostics",
tagof RMmsg.Commeventcounter => "Commeventcounter",
tagof RMmsg.Commeventlog => "Commeventlog",
tagof RMmsg.Writecoils => "Writecoils",
tagof RMmsg.Writeregisters => "Writeregisters",
tagof RMmsg.Slaveid => "Slaveid",
tagof RMmsg.Readfilerecord => "Readfilerecord",
tagof RMmsg.Writefilerecord => "Writefilerecord",
tagof RMmsg.Maskwriteregister => "Maskwriteregister",
tagof RMmsg.Rwregisters => "Rwregisters",
tagof RMmsg.Readfifo => "Readfifo",
tagof RMmsg.Encapsulatedtransport => "Encapsulatedtransport",
};

RMmsg.text(t: self ref RMmsg): string
{
	if(t == nil)
		return "(nil)";
	s := sys->sprint("RMmsg.%s(%d", rmsgname[tagof t], t.fcode);
	return s+")";
}

readmsg(fd: ref Sys->FD, msglim: int): (array of byte, string)
{
	sys->werrstr("readmsg unimplemented");
	return (nil, sys->sprint("%r"));
}

rtupack(addr: byte, pdu: array of byte): array of byte
{
	n := BIT8SZ + len pdu + BIT16SZ;
	c := rtucrc(addr, pdu);
	atu := array[n] of byte;
	atu[0] = addr;
	atu[1:] = pdu;
	atu[n-2] = byte(c >> 8);
	atu[n-1] = byte(c);
	return atu;
}

rtuunpack(data: array of byte): (byte, array of byte, int, string)
{
	e : string;
	addr : byte;
	pdu : array of byte;
	c : int;
	n := len data;
	if(n >= 4) {
		addr = data[0];
		pdu = data[1:n-2];
		c = (int data[n-2] << 8 | int data[n-1]);
		if(c != rtucrc(addr, pdu))
			e = "crc failed";
	} else
		e = "too short for an rtu packet";
	return (addr, pdu, c, e);
}

rtucrc(addr: byte, pdu: array of byte): int
{
	crc_state: ref CRCstate;
	crc_state = crc->init(POLY, SEED);
	
	n := len pdu + BIT8SZ;
	b := array[n] of byte;
	b[0] = addr;
	b[1:] = pdu;
	return crc->crc(crc_state, b, n);
}
