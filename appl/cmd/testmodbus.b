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
	RMmsg, TMmsg, rtupack, rtuunpack, rtucrc: import modbus;

stdin, stdout, stderr: ref Sys->FD;

TestModbus: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

Port: adt
{
	mode:	int;
	
	local:	string;
	ctl:	ref Sys->FD;
	rfd:	ref Sys->FD;
	wfd:	ref Sys->FD;

	rdlock: ref Lock->Semaphore;
	wrlock:	ref Lock->Semaphore;

	# input reader
	avail:	array of byte;
	pid:	int;

	rtusilent:	int;

	write:	fn(p: self ref Port, b: array of byte): int;
};

Port.write(p: self ref Port, b: array of byte): int
{
	r := 0;
	if(b != nil && len b > 0) {
		p.wrlock.obtain();
		if(p.mode == Modbus->ModeRTU)
			sys->sleep(p.rtusilent);
		r = sys->write(p.wfd, b, len b);
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
	skip := 0;
	
	arg := load Arg Arg->PATH;
	arg->init(argv);
	arg->setusage(arg->progname()+" [-d] [-s] [path]");
	while((c := arg->opt()) != 0)
		case c {
		'd' =>	dflag++;
		's' => skip++;
		* =>	arg->usage();
		}

	argv = arg->argv();
	if(argv != nil)
		path = hd argv;

	if(path != nil && skip == 0) {
		port = open(path);
		if(port.ctl == nil || port.rfd == nil) {
			sys->fprint(stderr, "Failed to connect to %s\n", port.local);
			exit;
		}
	}

#	if(path == "tcp!iolan!exactus") {
	if(path != nil) {
		sys->sleep(125);
		purge(port);
		exactus();
	} else {
		# TCP test
		b := array[] of {
			byte 16r00, byte 16r00, byte 16r00, byte 16r00, byte 16r00,
			byte 16r06, byte 16r01, byte 16r01, byte 16r00, byte 16r00,
			byte 16r00, byte 16r01
		};
		test(port, b);

		b = array[] of {
			byte 16r00, byte 16r00, byte 16r00, byte 16r00, byte 16r00,
			byte 16r06, byte 16r01, byte 16r02, byte 16r00, byte 16r00,
			byte 16r00, byte 16r01
		};
		test(port, b);
	}

	Hangup:= array[] of {byte "hangup"};
	if(dflag) sys->fprint(stderr, "\nexiting...\n");
	if(port != nil)
		if(port.ctl != nil) {
			sys->write(port.ctl, Hangup, len Hangup);
			close(port);
		}
}

test(p: ref Port, b: array of byte)
{
	if(p != nil) {
		start := sys->millisec();
		n := p.write(b);
		stop := sys->millisec();
		sys->fprint(stderr, "TX -> %s (%d, %d)\n", hexdump(b), n, stop-start);

		r := readreply(p, 500);
		if(r != nil)
			sys->fprint(stderr, "reply: %s\n", hexdump(r.pack()));
		else {
			p.rdlock.obtain();
			sys->fprint(stderr, "RX <- %s\n", hexdump(port.avail));
			p.rdlock.release();
		}
	}
}

exactus()
{
	m : ref TMmsg;
	b := array[] of {
		byte 16r02, byte 16r4d, byte 16r4d, byte 16r03,
	};
	
	addr := byte 16r01;
	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 0, 16r0002);
	pdu := b[1:len b - 2];
	_pdu := m.pack();
	rtu := rtupack(addr, m.pack());
	
#	sys->fprint(stderr, "bytes: %s\n", hexdump(b));
#	sys->fprint(stderr, "  pdu: %s\n", hexdump(pdu));
#	sys->fprint(stderr, "  rtu: %s\n", hexdump(rtu));
#	sys->fprint(stderr, " _pdu: %s\n", hexdump(_pdu));
#	sys->fprint(stderr, " _pdu crc: %04X\n", modbus->rtucrc(addr, _pdu));
#	sys->fprint(stderr, " test: %04X\n", modbus->rtucrc_test(addr, m.pack()));
	
#	timingtest(addr, _pdu);

	test(port, b);
	purge(port);

	test(port, rtu);
	purge(port);
	sys->sleep(30);
	
	b = array[] of {
		byte 16r00, byte 16r03, byte 16r11, byte 16r00, byte 16r00, byte 16r31,
		byte 16rff, byte 16r40
	};
	test(port, b);
	purge(port);

	b = array[] of {
		byte 16r00, byte 16r03, byte 16r00, byte 16r11, byte 16r31, byte 16r00,
		byte 16rff, byte 16r40
	};
	test(port, b);
	purge(port);
	
	b = array[] of {
		byte 16r00, byte 16r03, byte 16r00, byte 16r11, byte 16r31, byte 16r00,
		byte 16r40, byte 16rff
	};
	test(port, b);
	purge(port);

	b = b[0:len b - 2];
	test(port, b);
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r1100, 32);
	rtu = rtupack(byte 1, m.pack());
	test(port, rtu);
	purge(port);
	
#	word := g16(rtu, len rtu - 2);
#	word = swap(word);
#	rtu[len rtu - 2] = byte (word);
#	rtu[len rtu - 1] = byte (word>>8);
#	test(port, rtu);
}

p16(a: array of byte, o: int, v: int): int
{
	a[o] = byte (v>>8);
	a[o+1] = byte v;
	return o+2;
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

purge(p: ref Port)
{
	p.rdlock.obtain();
	p.avail = array[0] of byte;
	p.rdlock.release();
}

open(path: string): ref Port
{
	np := ref Port;
	np.mode = Modbus->ModeRTU;
	np.rdlock = Semaphore.new();
	np.wrlock = Semaphore.new();
	np.local = path;
	np.pid = 0;
	np.rtusilent = 5;		# 5 ms, more than 3.5 char times a byte at 115.2kb

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

	p.rfd = nil;
	p.wfd = nil;
	p.ctl = nil;

	if(p.local != nil) {
		if(str->in('!', p.local)) {
			(ok, net) := sys->dial(p.local, nil);
			if(ok == -1) {
				raise "can't open "+p.local;
				return;
			}

			p.ctl = sys->open(net.dir+"/ctl", Sys->ORDWR);
			p.rfd = sys->open(net.dir+"/data", Sys->OREAD);
			p.wfd = sys->open(net.dir+"/data", Sys->OWRITE);
		} else {
			p.ctl = sys->open(p.local+"ctl", Sys->ORDWR);
			p.rfd = sys->open(p.local, Sys->OREAD);
			p.wfd = sys->open(p.local, Sys->OWRITE);
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
		while((n := sys->read(p.rfd, buf, len buf)) > 0) {
			p.rdlock.obtain();
			if(len p.avail < Sys->ATOMICIO) {
				na := array[len p.avail + n] of byte;
				na[0:] = p.avail[0:];
				na[len p.avail:] = buf[0:n];
				p.avail = na;
			}
			p.rdlock.release();
		}
		sys->fprint(stderr, "reader closed\n");
		# error, try again
		p.rfd = nil;
		p.wfd = nil;
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
	if(p.rfd == nil)
		return nil;
	c := ref sys->Connection(p.rfd, p.ctl, nil);
	p.ctl = nil;
	p.rfd = nil;
	p.wfd = nil;
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

# testing
timingtest(addr: byte, pdu: array of byte)
{
	sys->fprint(stderr, "\n");
	sys->fprint(stderr, "time crc16: ");
	start := sys->millisec();
	for(i:=0; i<1000000; i++)
		modbus->rtucrc(addr, pdu);
	stop := sys->millisec();
	ms := real(stop - start)/1000000.0;
	sys->fprint(stderr, "%g ms\n", ms);

	sys->fprint(stderr, "time rtucrc_test: ");
	start = sys->millisec();
	for(i=0; i<1000000; i++)
		modbus->rtucrc_test(addr, pdu);
	stop = sys->millisec();
	ms = real(stop - start)/1000000.0;
	sys->fprint(stderr, "%g ms\n", ms);
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
