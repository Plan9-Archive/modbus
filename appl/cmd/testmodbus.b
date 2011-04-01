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
		test(port, b, "tcp test");

		b = array[] of {
			byte 16r00, byte 16r00, byte 16r00, byte 16r00, byte 16r00,
			byte 16r06, byte 16r01, byte 16r02, byte 16r00, byte 16r00,
			byte 16r00, byte 16r01
		};
		test(port, b, "tcp test");
	}

	Hangup:= array[] of {byte "hangup"};
	if(dflag) sys->fprint(stderr, "\nexiting...\n");
	if(port != nil)
		if(port.ctl != nil) {
			sys->write(port.ctl, Hangup, len Hangup);
			close(port);
		}
}

test(p: ref Port, b: array of byte, s: string)
{
	if(p != nil) {
		sys->fprint(stdout, "\nTest: %s\n", s);
		start := sys->millisec();
		n := p.write(b);
		stop := sys->millisec();
		sys->fprint(stdout, "TX -> %s\t(%d, %d)\n", hexdump(b), n, stop-start);

		(addr, r, crc, err) := readreply(p, 500);
		if(r != nil) {
			sys->fprint(stdout, "RMmsg (addr=%d, crc=%d err='%s'): %s\n",
						int addr, crc, err, r.text());
			buf := r.pack();
			sys->fprint(stdout, "reply: %s\n", hexdump(buf[0:2]));
			sys->fprint(stdout, "%s\n", hexdump(buf[2:]));
		} else {
			p.rdlock.obtain();
			sys->fprint(stdout, "RX <- %s\n", hexdump(port.avail));
			p.rdlock.release();
		}
	}
}

exactus()
{
	m : ref TMmsg;
	addr := byte 16r01;
	b := array[] of {
		byte 16r02, byte 16r4d, byte 16r4d, byte 16r03,
	};
	rtu : array of byte;

	test(port, b, "force modbus mode");
	purge(port);
	
	m = ref TMmsg.Readcoils(Modbus->Treadcoils, 1, 32);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read coils");
	purge(port);
	
	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r0000, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x0000) channel 1 temperature");
	purge(port);
	
	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r0004, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x0004) channel 1 current");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r0006, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x0006) channel 1 temperature");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r0012, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x0012) channel 1 current");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r0014, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x0014) channel 2 current -- dual channel models");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r0800, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x0800) chassis temperature");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r1000, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x1000) config register 1");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r1001, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x1001) config register 2");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r1007, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x1007) Modbus device address");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r1008, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x1008) Modbus baud rate");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r1011, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x1011) sampling rate");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r1100, 32);
	rtu = rtupack(byte 1, m.pack());
	test(port, rtu, "read (0x1100) name string buffer");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r1300, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x1300) Software version");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r1301, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x1301) Software build");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r1305, 16r0009);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x1305) Serial number (9 ASCII bytes)");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r2004, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x2004) Channel 1 Calibration Factor");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r2006, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x2006) Channel 1 Transmission Factor");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r2008, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x2008) Channel 1 Current Offset");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3000, 16r000F);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3000) Emissivity Table X Entries 0-7");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3010, 16r000F);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3010) Emissivity Table Y Entries 0-7");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3020, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3020) Emissivity Table Size");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3030, 16r000F);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3030) Fit Table X Entries 0-7");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3040, 16r000F);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3040) Fit Table Y Entries 0-7");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3050, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3050) Fit Table Size");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3060, 16r000F);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3060) Avg/BW Table X Entries 0-7");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3070, 16r000F);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3070) Avg/BW Table Y Entries 0-7");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3080, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3080) Average Table Size");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3100, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3100) Voltage Mode Min. Volts");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3102, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3102) Voltage Mode Max. Volts");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3104, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3104) Voltage Mode Min. Temp.");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3106, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3106) Voltage Mode Max. Temp.");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3110, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3110) Current Mode Min. Current");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3112, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3112) Current Mode Max. Current");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3114, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3114) Current Mode Min. Temp.");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r3116, 16r0002);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x3116) Current Mode Max. Temp.");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r8000, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x8000) Command Register");
	purge(port);

	m = ref TMmsg.Readholdingregisters(Modbus->Treadholdingregisters, 16r8003, 16r0001);
	rtu = rtupack(addr, m.pack());
	test(port, rtu, "read (0x8003) Manual Range Register");
	purge(port);
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

# returns (addr, ref RMmsg, crc, err)
getreply(p: ref Port): (byte, ref RMmsg, int, string)
{
	addr := byte 0;
	pdu : array of byte;
	crc : int;
	err : string;
	r: ref RMmsg;
	
	if(p==nil)
		return (addr, r, crc, "No valid port");

	p.rdlock.obtain();
	n := len p.avail;
	if(n >= 4) {
		(addr, pdu, crc, n, err) = modbus->rtuunpack(p.avail);
		if(err == nil && n > 0) {
			(t, m) := RMmsg.unpack(pdu);
			if(t > 0)
				 r = m;
			else {
				sys->fprint(stderr, "RMmsg.unpack(): %d\n", t);
				sys->fprint(stderr, "RX <- %s\n", hexdump(p.avail));
			}
			p.avail = p.avail[n:];
		} else if(err == Modbus->ERR_RTUCRC) {
			if(n > 0)
				p.avail = p.avail[n:];
		}
	}
	p.rdlock.release();

	return (addr, r, crc, err);
}

# read until timeout or result is returned
readreply(p: ref Port, ms: int): (byte, ref RMmsg, int, string)
{
	addr := byte 0;
	crc : int;
	err : string;
	r: ref RMmsg;

	if(p == nil)
		return (byte 0, nil, 0, "No valid port");

	limit := 60000;			# arbitrary maximum of 60s
	for(start := sys->millisec(); sys->millisec() <= start+ms;) {
		(addr, r, crc, err) = getreply(p);
		if(r == nil) {
			if(limit--) {
				sys->sleep(1);
				continue;
			}
			break;
		} else
			break;
	}

	return (addr, r, crc, err);
}

# testing
timingtest(addr: byte, pdu: array of byte)
{
	sys->fprint(stdout, "\n");
	sys->fprint(stdout, "time crc16: ");
	start := sys->millisec();
	for(i:=0; i<1000000; i++)
		modbus->rtucrc(addr, pdu);
	stop := sys->millisec();
	ms := real(stop - start)/1000000.0;
	sys->fprint(stdout, "%g ms\n", ms);

	sys->fprint(stdout, "time rtucrc_test: ");
	start = sys->millisec();
	for(i=0; i<1000000; i++)
		modbus->rtucrc_test(addr, pdu);
	stop = sys->millisec();
	ms = real(stop - start)/1000000.0;
	sys->fprint(stdout, "%g ms\n", ms);
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

kill(pid: int)
{
	fd := sys->open("#p/"+string pid+"/ctl", Sys->OWRITE);
	if(fd == nil || sys->fprint(fd, "kill") < 0)
		sys->print("testmodbus: can't kill %d: %r\n", pid);
}
