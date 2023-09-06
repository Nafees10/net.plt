module netplt;

import std.stdio,
			 std.conv;

import core.runtime;

import daplt.daplt;

extern (C) PObj init(){
	Runtime.initialize;
	return moduleCreate!(mixin(__MODULE__))("netplt").obj;
}
