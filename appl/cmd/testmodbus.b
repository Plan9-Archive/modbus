implement TestModbus;

include "sys.m";
include "draw.m";
include "dial.m";
include "arg.m";
include "lock.m";
include "string.m";

include "modbus.m";

sys: Sys;
draw: Draw;
dial: Dial;
str: String;

modbus: Modbus;

stdin, stdout, stderr: ref Sys->FD;

TestModbus: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

Port: adt
{
	mode:	int;

	local:	string;
	ctl:	ref Sys->FD;
	data:	ref Sys->FD;
};

p: ref Port;
dflag := 0;

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	dial = load Dial Dial->PATH;
	str = load String String->PATH;

	stderr = sys->fildes(2);
	stdout = sys->fildes(1);
	stdin = sys->fildes(0);

	modbus = load Modbus Modbus->PATH;
	modbus->init();
	
	path := "tcp!iolan!exactus";

	arg := load Arg Arg->PATH;
	arg->init(argv);
	arg->setusage(arg->progname()+" [-d] [path]");
	while((c := arg->opt()) != 0)
		case c {
		'd' =>	dflag++;
		* =>	arg->usage();
		}

	argv = arg->argv();
	if(argv != nil)
		path = hd argv;

	if(path != nil) {
		p = ref Port(Modbus->ModeRTU, nil, nil, nil);
		p.local = path;
		if(str->in('!', p.local)) {
			(ok, net) := sys->dial(p.local, nil);
			if(ok == -1) {
				raise "can't open "+p.local;
				exit;
			}
			p.ctl = sys->open(net.dir+"/ctl", Sys->ORDWR);
			p.data = sys->open(net.dir+"/data", Sys->ORDWR);
		} else {
			p.ctl = sys->open(p.local+"ctl", Sys->ORDWR);
			p.data = sys->open(p.local, Sys->ORDWR);
		}
	}

	b := array[] of {
		byte 16r01, byte 16r05, byte 16r00, byte 16r13, byte 16r00, byte 16r00,
		byte 16r3c, byte 16r0f
		};
	sys->write(p.data, b, len b);
	sys->fprint(stderr, "TX -> %s\n", dump(b));
	
	b = array[] of {
		byte 16r02, byte 16r56, byte 16r56, byte 16r03
	};
	sys->write(p.data, b, len b);
	sys->fprint(stderr, "TX -> %s\n", dump(b));
	
	buf := array[1] of byte;
	while (1) {
		sys->read(p.data, buf, len buf);
		sys->fprint(stderr, "RX -> %s\n", dump(buf));
	}
	
	Hangup:= array[] of {byte "hangup"};
	if(dflag) sys->fprint(stderr, "\nexiting...\n");
	if(p.ctl != nil)
		sys->write(p.ctl, Hangup, len Hangup);

	p.ctl = nil;
	p.data = nil;
}

dump(b: array of byte): string
{
	s := "";
	for(i:=0; i<len b; i++)
		s = sys->sprint("%s %02X", s, int(b[i]));
	return s;
}
