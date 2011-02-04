implement Modbus;

include "sys.m";
include "modbus.m";

sys: Sys;

BIT8SZ:	con 1;
BIT16SZ:	con 2;

H: con BIT8SZ;		# minimum PDU header length: tag[1]

init()
{
	sys = load Sys Sys->PATH;
}


hdrlen := array[Tmax] of {
Rerror =>	H+BIT8SZ,
Treadcoils =>	H+BIT16SZ+BIT16SZ,
Rreadcoils =>	H+BIT8SZ,
Treaddiscreteinputs => H+BIT16SZ+BIT16SZ,
Rreaddiscreteinputs => H+BIT8SZ,
Treadholdingregisters => H+BIT16SZ+BIT16SZ,
Rreadholdingregisters => H+BIT8SZ,
Treadinputregisters => H+BIT16SZ+BIT16SZ,
Rreadinputregisters => H+BIT8SZ,
Twritecoil => H+BIT16SZ+BIT16SZ,
Rwritecoil => H+BIT16SZ+BIT16SZ,
Twriteregister => H+BIT16SZ+BIT16SZ,
Rwriteregister => H+BIT16SZ+BIT16SZ,
Treadexception => H,
Rreadexception => H+BIT8SZ,
Tdiagnostics => H+BIT16SZ,
Rdiagnostics => H+BIT16SZ,
Tcommeventcounter => H,
Rcommeventcounter => H+BIT16SZ+BIT16SZ,
Tcommeventlog => H,
Rcommeventlog => H+BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ,
Twritecoils => H+BIT16SZ+BIT16SZ+BIT8SZ,
Rwritecoils => H+BIT16SZ+BIT16SZ,
Twriteregisters => H+BIT16SZ+BIT16SZ+BIT8SZ,
Rwriteregisters => H+BIT16SZ+BIT16SZ,
Tslaveid => H,
Rslaveid => H+BIT8SZ+BIT8SZ,		# tag[1] count[1] id[n] status[1] data[n]
Treadfilerecord => H+BIT8SZ+BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ,
Rreadfilerecord => H+BIT8SZ+BIT8SZ+BIT8SZ+BIT16SZ,
Twritefilerecord => H+BIT8SZ+BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ+BIT16SZ,
Rwritefilerecord => H+BIT8SZ+BIT8SZ+BIT16SZ+BIT16SZ+BIT16SZ+BIT16SZ,
Tmaskwriteregister => H+BIT16SZ+BIT16SZ+BIT16SZ,
Rmaskwriteregister => H++BIT16SZ+BIT16SZ+BIT16SZ,
Trdwrregisters => H+BIT16SZ+BIT16SZ+BIT16SZ+BIT16SZ+BIT8SZ+BIT16SZ,
Rrdwrregisters => H+BIT8SZ+BIT16SZ,
Treadfifo => H+BIT16SZ,
Rreadfifo => H++BIT16SZ+BIT16SZ+BIT16SZ,
Tencapsulatedinterface => H+BIT8SZ,
Rencapsulatedinterface => H+BIT8SZ,
};

tag2type := array[] of {
tagof Mmsg.Rerror => Rerror,
tagof Mmsg.Treadcoils => Treadcoils,
tagof Mmsg.Rreadcoils => Rreadcoils,
tagof Mmsg.Treaddiscreteinputs => Treaddiscreteinputs,
tagof Mmsg.Rreaddiscreteinputs => Rreaddiscreteinputs,
tagof Mmsg.Treadholdingregisters => Treadholdingregisters,
tagof Mmsg.Rreadholdingregisters => Rreadholdingregisters,
tagof Mmsg.Treadinputregisters => Treadinputregisters,
tagof Mmsg.Rreadinputregisters => Rreadinputregisters,
tagof Mmsg.Twritecoil => Twritecoil,
tagof Mmsg.Rwritecoil => Rwritecoil,
tagof Mmsg.Twriteregister => Twriteregister,
tagof Mmsg.Rwriteregister => Rwriteregister,
tagof Mmsg.Treadexception => Treadexception,
tagof Mmsg.Rreadexception => Rreadexception,
tagof Mmsg.Tdiagnostics => Tdiagnostics,
tagof Mmsg.Rdiagnostics => Rdiagnostics,
tagof Mmsg.Tcommeventcounter => Tcommeventcounter,
tagof Mmsg.Rcommeventcounter => Rcommeventcounter,
tagof Mmsg.Tcommeventlog => Tcommeventlog,
tagof Mmsg.Rcommeventlog => Rcommeventlog,
tagof Mmsg.Twritecoils => Twritecoils,
tagof Mmsg.Rwritecoils => Rwritecoils,
tagof Mmsg.Twriteregisters => Twriteregisters,
tagof Mmsg.Treadregisters => Treadregisters,
tagof Mmsg.Tslaveid => Tslaveid,
tagof Mmsg.Rslaveid => Rslaveid,
tagof Mmsg.Treadfilerecord => Treadfilerecord,
tagof Mmsg.Rreadfilerecord => Rreadfilerecord,
tagof Mmsg.Twritefilerecord => Twritefilerecord,
tagof Mmsg.Rwritefilerecord => Rwritefilerecord,
tagof Mmsg.Tmaskwriteregister => Tmaskwriteregister,
tagof Mmsg.Rmaskwriteregister => Rmaskwriteregister,
tagof Mmsg.Trdwrregisters => Trdwrregisters,
tagof Mmsg.Rrdwrregisters => Rrdwrregisters,
tagof Mmsg.Treadfifo => Treadfifo,
tagof Mmsg.Rreadfifo => Rreadfifo,
tagof Mmsg.Tencapsulatedinterface => Tencapsulatedinterface,
tagof Mmsg.Rencapsulatedinterface => Rencapsulatedinterface,
};

msgname := array[] of {
tagof Mmsg.Rerror => "Rerror",
tagof Mmsg.Treadcoils => "Treadcoils",
tagof Mmsg.Rreadcoils => "Rreadcoils",
tagof Mmsg.Treaddiscreteinputs => "Treaddiscreteinputs",
tagof Mmsg.Rreaddiscreteinputs => "Rreaddiscreteinputs",
tagof Mmsg.Treadholdingregisters => "Treadholdingregisters",
tagof Mmsg.Rreadholdingregisters => "Rreadholdingregisters",
tagof Mmsg.Treadinputregisters => "Treadinputregisters",
tagof Mmsg.Rreadinputregisters => "Rreadinputregisters",
tagof Mmsg.Twritecoil => "Twritecoil",
tagof Mmsg.Rwritecoil => "Rwritecoil",
tagof Mmsg.Twriteregister => "Twriteregister",
tagof Mmsg.Rwriteregister => "Rwriteregister",
tagof Mmsg.Treadexception => "Treadexception",
tagof Mmsg.Rreadexception => "Rreadexception",
tagof Mmsg.Tdiagnostics => "Tdiagnostics",
tagof Mmsg.Rdiagnostics => "Rdiagnostics",
tagof Mmsg.Tcommeventcounter => "Tcommeventcounter",
tagof Mmsg.Rcommeventcounter => "Rcommeventcounter",
tagof Mmsg.Tcommeventlog => "Tcommeventlog",
tagof Mmsg.Rcommeventlog => "Rcommeventlog",
tagof Mmsg.Twritecoils => "Twritecoils",
tagof Mmsg.Rwritecoils => "Rwritecoils",
tagof Mmsg.Twriteregisters => "Twriteregisters",
tagof Mmsg.Treadregisters => "Treadregisters",
tagof Mmsg.Tslaveid => "Tslaveid",
tagof Mmsg.Rslaveid => "Rslaveid",
tagof Mmsg.Treadfilerecord => "Treadfilerecord",
tagof Mmsg.Rreadfilerecord => "Rreadfilerecord",
tagof Mmsg.Twritefilerecord => "Twritefilerecord",
tagof Mmsg.Rwritefilerecord => "Rwritefilerecord",
tagof Mmsg.Tmaskwriteregister => "Tmaskwriteregister",
tagof Mmsg.Rmaskwriteregister => "Rmaskwriteregister",
tagof Mmsg.Trdwrregisters => "Trdwrregisters",
tagof Mmsg.Rrdwrregisters => "Rrdwrregisters",
tagof Mmsg.Treadfifo => "Treadfifo",
tagof Mmsg.Rreadfifo => "Rreadfifo",
tagof Mmsg.Tencapsulatedinterface => "Tencapsulatedinterface",
tagof Mmsg.Rencapsulatedinterface => "Rencapsulatedinterface",
};

Mmsg.read(fd: ref Sys->FD): (ref Mmsg, string)
{
	(msg, err) := readmsg(fd);
	if(err != nil)
		return (nil, err);
	if(msg == nil)
		return (nil, "eof reading message");
	(nil, m) := Mmsg.unpack(msg);
	if(m == nil)
		return (nil, sys->spring("bad modbus message format: %r"));
	return (m, nil);
}

Mmsg.unpack(f: array of byte): (int, ref Mmsg)
{
	if(len f < H) {
		sys->werrstr("message too small");
		return (0, nil);
	}
	mtype := int f[0];
	
}
