module std::encoding::codepage_test;

import std::encoding::codepage::cp437;
import std::encoding::codepage::cp850;
import std::encoding::codepage::cp866;
import std::encoding::codepage::cp863;
import std::encoding::codepage::iso_8859_1;
import std::encoding::codepage::iso_8859_2;

alias DecodeFn @local = fn String?(Allocator,char[]);
alias EncodeFn @local = fn char[]?(Allocator,char[], char);

fn void test_cp437_roundtrip() @test
{
    // Box drawing + some Latin‑1‑ish characters you know are in CP437.
    String s = "╔══ CP437: Café, π≈3.14 ══╗";
    check_roundtrip(s, &cp437::decode, &cp437::encode);
}

fn void test_cp850_roundtrip() @test
{
    String s = "CP850: Crème Brûlée, Frühstück, £10.50";
    check_roundtrip(s, &cp850::decode, &cp850::encode);
}

fn void test_cp866_roundtrip() @test
{
    String s = "CP866: Привет мир!";
    check_roundtrip(s, &cp866::decode, &cp866::encode);
}

fn void test_cp863_roundtrip() @test
{
    String s = "CP863: Québec, érable, Noël";
    check_roundtrip(s, &cp863::decode, &cp863::encode);
}

fn void test_iso8859_1() @test
{
    String s = "ISO-8859-1: Café, Ångström, Straße, Noël, £10.50";
    check_roundtrip(s, &iso_8859_1::decode, &iso_8859_1::encode);
}

fn void test_iso8859_2_polish() @test
{
    String s = "Polski: Zażółć gęślą jaźń";
    check_roundtrip(s, &iso_8859_2::decode, &iso_8859_2::encode);
}

fn void test_iso8859_2_czech() @test
{
    String s = "Česky: Příliš žluťoučký kůň úpěl ďábelské ódy";
    check_roundtrip(s, &iso_8859_2::decode, &iso_8859_2::encode);
}

fn void test_iso8859_2_hungarian() @test
{
    String s = "Magyar: Árvíztűrő tükörfúrógép";
    check_roundtrip(s, &iso_8859_2::decode, &iso_8859_2::encode);
}

fn void check_roundtrip(String utf8, DecodeFn decode_fn, EncodeFn encode_fn) => @pool()
{
	// Encode UTF‑8 to code page.
	char[] bytes = encode_fn(tmem, utf8[..], codepage::REPLACEMENT_CHAR)!!;

	// Decode back to UTF‑8 and compare.
	String got = decode_fn(tmem, bytes)!!;

	assert(got == utf8,
		"roundtrip failed: got=%s, want=%s", got, utf8);
}
