# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder

name = "polymake"
version = v"3.3"

# Collection of sources required to build polymake
sources = [
    "https://github.com/polymake/polymake.git" =>
    "23998a2295038522d8ffee8e0715e68ea7f8c099",

]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/polymake
# bundled nauty needs working CPP
export CPP=cpp
./configure --prefix=${prefix} CFLAGS="-Wno-error" CC=gcc CXX=g++ --with-gmp=${prefix} PERL=${prefix}/bin/perl --without-native
ninja -v -C build/Opt -j$(( nproc / 2 ))
# avoid having an empty shared object which binary builder doesnt like
[ -s build/Opt/lib/ideal.so ] || \
g++ -shared -Wl,--as-needed --sysroot=/opt/$target/$target/sys-root -o build/Opt/lib/ideal.so -lc
ninja -v -C build/Opt install
# prepare paths for replacement after install
/workspace/destdir/bin/perl -pi -e "s#${prefix}#REPLACEPREFIX#g" ${prefix}/lib/polymake/config.ninja ${prefix}/bin/polymake-config ${prefix}/bin/polymake
# remove sysroot argument
/workspace/destdir/bin/perl -pi -e 's/--sysroot[= ][^ ]+//g' ${prefix}/lib/polymake/config.ninja
# prepare rpath for binarybuilder
patchelf --set-rpath $(patchelf --print-rpath ${prefix}/lib/libpolymake.so | sed -e "s#${prefix}/lib/#\$ORIGIN/#g") ${prefix}/lib/libpolymake.so
for lib in ${prefix}/lib/polymake/lib/*.so; do
   patchelf --set-rpath "\$ORIGIN/../.." $lib;
done
patchelf --set-rpath "\$ORIGIN/../../../../../../.." ${prefix}/lib/polymake/perlx/*/*/auto/Polymake/Ext/Ext.so
# tests need Time::HiRes ...
# /workspace/destdir/bin/perl perl/polymake --script run_testcases --examples '*'

"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
#TODO: platforms = supported_platforms()
platforms = [
    Linux(:x86_64, libc=:glibc, compiler_abi=CompilerABI(:gcc8))
    Linux(:x86_64, libc=:glibc, compiler_abi=CompilerABI(:gcc7))
    Linux(:x86_64, libc=:glibc, compiler_abi=CompilerABI(:gcc6))
    Linux(:i686, libc=:glibc, compiler_abi=CompilerABI(:gcc8))
    Linux(:i686, libc=:glibc, compiler_abi=CompilerABI(:gcc7))
    Linux(:i686, libc=:glibc, compiler_abi=CompilerABI(:gcc6))
]

# The products that we will ensure are always built
# TODO: we cannot use libpolymake as product as this picks up libpolymake-apps ...
products(prefix) = [
#    LibraryProduct(prefix, "libpolymake", :libpolymake)
    ExecutableProduct(prefix,"polymake", :polymake)
    ExecutableProduct(prefix,"polymake-config", Symbol("polymake_config"))
]

# Dependencies that must be installed before this package can be built
dependencies = [
    "https://github.com/bicycle1885/ZlibBuilder/releases/download/v1.0.3/build_Zlib.v1.2.11.jl",
    "https://github.com/benlorenz/XML2Builder/releases/download/v1.0.1-1/build_XML2Builder.v2.9.7.jl",
    "https://github.com/benlorenz/boostBuilder/releases/download/v1.67.0/build_boost.v1.67.0.jl",
    "https://github.com/benlorenz/MPFRBuilder/releases/download/v4.0.1-3/build_MPFR.v4.0.1.jl",
    "https://github.com/benlorenz/GMPBuilder/releases/download/v6.1.2-2/build_GMP.v6.1.2.jl",
    "https://github.com/benlorenz/perlBuilder/releases/download/v5.28.0/build_perl.v5.28.0.jl",
    "https://github.com/benlorenz/XSLTBuilder/releases/download/v1.1.32/build_XSLTBuilder.v1.1.32.jl"
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)

