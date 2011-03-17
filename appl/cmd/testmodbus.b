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
lock: Lock;
	Semaphore: import lock;
str: String;

modbus: Modbus;
	RMmsg, TMmsg: import modbus;

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

	rdlock: ref Lock->Semaphore;
	wrlock:	ref Lock->Semaphore;

	# input reader
	avail:	array of byte;
	pid:	int;

	write:	fn(p: self ref Port, b: array of byte): int;
};

Port.write(p: self ref Port, b: array of byte): int
{
	r := 0;
	if(b != nil && len b > 0) {
		p.wrlock.obtain();
		r = sys->write(p.data, b, len b);
		p.wrlock.release();
	}
	return r;
}

port: ref Port;
dflag := 0;

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	dial = load Dial Dial->PATH;
	str = load String String->PATH;
	lock = load Lock Lock->PATH;
	if(lock == nil)
		raise "fail: could not load lock module";
	lock->init();

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
		port = open(path);
		if(port.ctl == nil || port.data == nil) {
			sys->fprint(stderr, "Failed to connect to %s\n", port.local);
			exit;
		}
	}

	b := array[] of {
		byte 16r01, byte 16r03, byte 16r00, byte 16r00, byte 16r00, byte 16r02,
		byte 16rc4, byte 16r0b
		};
	port.write(b);
	sys->fprint(stderr, "TX -> %s\n", hexdump(b));
	
	r := readreply(port, 500);
	if(r != nil)
		sys->fprint(stderr, "reply: %s\n", hexdump(r.pack()));
	
	b = array[] of {
		byte 16r02, byte 16r56, byte 16r56, byte 16r03
	};
	port.write(b);
	sys->fprint(stderr, "TX -> %s\n", hexdump(b));

	r = readreply(port, 500);
	if(r != nil)
		sys->fprint(stderr, "reply: %s\n", hexdump(r.pack()));

	port.rdlock.obtain();
	sys->fprint(stderr, "RX <- %s\n", hexdump(port.avail));
	port.rdlock.release();

	Hangup:= array[] of {byte "hangup"};
	if(dflag) sys->fprint(stderr, "\nexiting...\n");
	if(port.ctl != nil)
		sys->write(port.ctl, Hangup, len Hangup);

	close(port);
}




open(path: string): ref Port
{
	np := ref Port;
	np.mode = Modbus->ModeRTU;
	np.rdlock = Semaphore.new();
	np.wrlock = Semaphore.new();
	np.local = path;
	np.pid = 0;

	openport(np);
	if(np.ctl != nil)
		reading(np);

	return np;
}

# prepare device port
openport(p: ref Port)
{
	if(p==nil) {
		raise "fail: port not initialized";
		return;
	}

	p.data = nil;
	p.ctl = nil;

	if(p.local != nil) {
		if(str->in('!', p.local)) {
			(ok, net) := sys->dial(p.local, nil);
			if(ok == -1) {
				raise "can't open "+p.local;
				return;
			}

			p.ctl = sys->open(net.dir+"/ctl", Sys->ORDWR);
			p.data = sys->open(net.dir+"/data", Sys->ORDWR);
		} else {
			p.ctl = sys->open(p.local+"ctl", Sys->ORDWR);
			p.data = sys->open(p.local, Sys->ORDWR);
		}
	}

	p.avail = nil;
}

reading(p: ref Port)
{
	if(p.pid == 0) {
		pidc := chan of int;
		spawn reader(p, pidc);
		p.pid = <-pidc;
	}
}

reader(p: ref Port, pidc: chan of int)
{
	pidc <-= sys->pctl(0, nil);

	buf := array[1] of byte;
	for(;;) {
		while((n := sys->read(p.data, buf, len buf)) > 0) {
			p.rdlock.obtain();
			if(len p.avail < Sys->ATOMICIO) {
				na := array[len p.avail + n] of byte;
				na[0:] = p.avail[0:];
				na[len p.avail:] = buf[0:n];
				p.avail = na;
			}
			p.rdlock.release();
		}
		# error, try again
		p.data = nil;
		p.ctl = nil;
		openport(p);
	}
}

# shut down reader (if any)
close(p: ref Port): ref Sys->Connection
{
	if(p == nil)
		return nil;

	if(p.pid != 0){
		kill(p.pid);
		p.pid = 0;
	}
	if(p.data == nil)
		return nil;
	c := ref sys->Connection(p.data, p.ctl, nil);
	p.ctl = nil;
	p.data = nil;
	return c;
}

getreply(p: ref Port): ref RMmsg
{
	if(p==nil)
		return nil;

	r: ref RMmsg;
	p.rdlock.obtain();
	if(len p.avail >= 5) {
		(n, m) := RMmsg.unpack(p.avail[1:]);
		if(n > 0 && len p.avail > n+3) {
			(addr, pdu, crc, err) := modbus->rtuunpack(p.avail[0:n+3]);
			if(err != nil) {
				r = m;
				p.avail = p.avail[(n+3):];
			} else {
				sys->fprint(stderr, "RX -> %s\n", hexdump(p.avail));
				sys->fprint(stderr, "error: %s\n", err);
				sys->fprint(stderr, "data: %d %s %d\n", int addr, hexdump(pdu), crc);
			}
		}
	}
	p.rdlock.release();

	return r;
}

# read until timeout or result is returned
readreply(p: ref Port, ms: int): ref RMmsg
{
	if(p == nil)
		return nil;

	limit := 60000;			# arbitrary maximum of 60s
	r : ref RMmsg;
	for(start := sys->millisec(); sys->millisec() <= start+ms;) {
		r = getreply(p);
		if(r == nil) {
			if(limit--) {
				sys->sleep(1);
				continue;
			}
			break;
		} else
			break;
	}

	return r;
}


hexdump(b: array of byte): string
{
	s := "";
	for(i:=0; i<len b; i++)
		s = sys->sprint("%s %02X", s, int(b[i]));
	return s;
}

kill(pid: int)
{
	fd := sys->open("#p/"+string pid+"/ctl", Sys->OWRITE);
	if(fd == nil || sys->fprint(fd, "kill") < 0)
		sys->print("testmodbus: can't kill %d: %r\n", pid);
}
