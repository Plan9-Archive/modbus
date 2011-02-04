implement TestExactus;

include "sys.m";
include "draw.m";
include "lock.m";

include "exactus.m";

sys: Sys;
draw: Draw;

exactus: Exactus;
	Instruction, Port: import exactus;

TestExactus: module {
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

init(ctxt: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	
	exactus = load Exactus Exactus->PATH;
	exactus->init();
	
#	tls := exactus->open("/dev/eia0");

	rfd := sys->open("/dev/eia0", Sys->OREAD);
	wfd := sys->open("/dev/eia0", Sys->OWRITE);
	
	b := array[] of {
		byte 16r01, byte 16r05, byte 16r00, byte 16r13, byte 16r00, byte 16r00,
		byte 16r3c, byte 16r0f
		};
	sys->write(wfd, b, len b);
	
	b = array[] of {
		byte 16r02, byte 16r56, byte 16r56, byte 16r03
	};
	sys->write(wfd, b, len b);
	
	buf := array[1] of byte;
	while (1) {
		sys->read(rfd, buf, len buf);
		dump(buf);
	}
#	write(tls, b);
#	read(tls);
#	read(tls);
#	read(tls);
#	read(tls);
#	
#	exactus->close(tls);
}

read(p: ref Exactus->Port): ref Exactus->Instruction
{
	r := exactus->readreply(p, 100);
	if(r != nil)
		sys->print("RX <- %s\n", dump(r.bytes()));
		return r;
	return r;
}

write(p: ref Exactus->Port, b: array of byte)
{
	sys->print("TX -> %s\n", dump(b));
	p.write(b);
}

dump(b: array of byte): string
{
	s := "";
	for(i:=0; i<len b; i++)
		s = sys->sprint("%s %02X", s, int(b[i]));
		s = sys->sprint("%s %s", s, string(b[2:]));
		return s;
}
