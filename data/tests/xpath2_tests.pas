unit xpath2_tests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;


procedure unittests;

implementation

uses xquery, simplehtmltreeparser, bbutils;


procedure unittests;
var
  i: Integer;
  ps: TXQueryEngine;
  xml: TTreeParser;

  procedure performUnitTest(s1,s2,s3: string);
  var got: string;
    rooted: Boolean;
  begin
    if s3 <> '' then begin
      rooted := s3[1] = '!';
      if rooted then s3[1] := ' ';
      xml.parseTree(s3);
      if rooted then ps.RootElement := xml.getLastTree
      else ps.RootElement:=nil;
    end;
    ps.parseXPath2(s1);
//    if strContains(s1, '/') then writeln(s1, ': ', ps.debugTermToString(ps.FCurTerm));
    ps.ParentElement := xml.getLastTree;
//    writeln(s1);
//    writeln('??');
//    writeln(ps.debugtermToString(ps.FCurTerm));
    got := ps.evaluate().toString;
    if got<>s2 then
       raise Exception.Create('XPath Test failed: '+IntToStr(i)+ ': '+s1+#13#10'got: "'+got+'" expected "'+s2+'"');
  end;

  procedure t(a,b: string; c: string = '');
  begin
    try
    performUnitTest(a,b,c);

    except on e:exception do begin
      writeln('Error @ "',a, '"');
      raise;
    end end;
  end;

//var  time: TDateTime;
var vars: TXQVariableChangeLog;
begin
//  time := Now;
  vars:= TXQVariableChangeLog.create();
  vars.addVariable('abc', 'alphabet');
  vars.addVariable('test', 'tset');
  vars.addVariable('eval', '''abc'' = ''abc''');

  ps := TXQueryEngine.Create;
  ps.StaticBaseUri := 'pseudo://test';
  ps.ImplicitTimezone:=-5 / HoursPerDay;
  ps.OnEvaluateVariable:=@vars.evaluateVariable;
  ps.OnDefineVariable:=@vars.defineVariable;
  xml := TTreeParser.Create;
  xml.readComments:=true;
  xml.readProcessingInstructions:=true;

  t('',                          '',                                 '');
  t('''''',                      '',                                 '');
  t('''Test''',                  'Test',                             '');
  t(#9'   ''xyz''     '#13#10,   'xyz',                              '');
  t(''''#9'xyz'#13'''',           #9'xyz'#13,                        '');
  t('"abc"',                     'abc',                              '');
  t('"''"',                      '''',                               '');
  t('"He said, ""I don''t like it."""', 'He said, "I don''t like it."', '');
  t('''He said, "I don''''t like it."''', 'He said, "I don''t like it."', '');


                //Variable tests
  t('"$$;"',                   '$',                            '');
  t('">$$;<"',                 '>$<',                          '');
  t('">$$;<"',                 '>$<',                          '');
  t('">$unknown;<"',           '><',                           '');
  t('"$test;>$unknown;<"',     'tset><',                       '');
  t('"$test;$unknown;$abc;"',  'tsetalphabet',                 '');
  t('$abc;',                     'alphabet',                     '');
  t('$abc',                     'alphabet',                     '');
  t('$ABC;',                     '',                           ''); //case sensitive
  t('$ABC',                     '',                            '');
  t('concat(">",$abc,''<'')',  '>alphabet<',                     '');
  t('''$abc;''',                   '$abc;',                        ''); //no variable matching in '
  t('"$abc;"',                   'alphabet',                        ''); //variable matching in "
  t('"$ABC;"',                   '',                        '');

  //change base xml used for tests
  t('','', '<html attrib1="FIRST ATTRIBUTE" attrib2="SECOND ATTRIBUTE" attrib3="THIRD ATTRIBUTE">test:last text<!--comment!--><deep>:BEEP</deep>'#13#10+
          '<adv><table id="t1"><tr><td><!-- cya -->first col</td><td bgcolor="red">2nd col</td></tr></table>'#13#10+
                '<table id="t2"><tr><td colspan=3><blink>OMG!!</blink></td></tr><tr><td>A</td><td>B</td><td empty="">C</td></tr></table></adv></html> ');

                //XPath like HTML Reading
  t('html/text()',               'test:last text',                   '');
  t('html/comment()',            'comment!',                         '');
  t('html/@attrib1',             'FIRST ATTRIBUTE',                  '');
  t('html/@attrib2',             'SECOND ATTRIBUTE',                 '');
  t('html/@attrib3',             'THIRD ATTRIBUTE',                  '');
  t('html/adv/text()',           '',                                 '');
t('html/adv/table/deep-text('' '')','first col 2nd col',           ''); //additional spaces!
  t('html/adv/table/@id',        't1',                               '');
  t('html/adv/table/tr/td/text()', 'first col',                      '');
  t('html/adv/table/tr/td/comment()', 'cya',                         '');
  t('html/adv/table[@id=''t2'']/@id','t2',                           '');
  t('html/adv/table[@id=''t2'']/tr/td/@colspan','3',                 '');
t('html/adv/table[@id=''t2'']/tr/td/text()','A',                   ''); //if this fails with OMG!! direct child also matches a direct grand child
  t('html/adv/table[@id=''t2'']/tr/td/deep-text('' '')','OMG!!',     '');
  t('html/adv/table[@id=''t2'']/tr/td[@colspan!=''3'']/text()','',''); //not existing property != 3

                //Comparison tests
                //('''a == b''',                'a == b',                           ''),
                //('''a'' == ''b''',            'false',                            ''),
                //('''abc'' == ''abc''',        'true',                             ''),
  t('''123'' != ''abc''',        'true',                             '');
  t('''a = b''',                'a = b',                           '');
  t('''a'' = ''b''',            'false',                            '');
  t('''abc'' = ''abc''',        'true',                             '');
  t('''123'' != ''abc''',        'true',                             '');
                //('''$test;''==''abc''',       'false',                            ''),
                //Concatenation tests
  t('concat(''a'',''b'',''c'')', 'abc',                              '');
  t('concat(''one'')',           'one',                              '');
  t('concat(''hallo'', '' '', ''welt'') = ''hallo welt''',  'true', '');
  t('concat  (  ''a'',  ''b'',  ''c''  )',                   'abc',  '');
  t('concat(''a'',''b'',concat(''c'',''d''))',               'abcd', '');
  t('concat(''a'',concat(''x'',''y'',''z''),''b'',''c'')',   'axyzbc','');
                //Concatenation + Comparison tests (double as stack test)
  t('concat(''cond is '',''abc''=''abc'')',                 'cond is true', '');
  t('concat(''>'',''123''!=''test'',''<'')',                 '>true<', '');
  t('concat(concat(''123'',''abc'')=''123abc'',''-#-'')',   'true-#-', '');
  t('concat(''('',''abc''=concat(''a'',''b'',''c''),'')'')','(true)', '');
                //Undefined/empty set
  t('html/adv/table[@id=''t2'']/tr/td[@not=@bot]/text()','','');
  t('html/adv/table[@id=''t2'']/tr/td[@not!=@bot]/text()','','');
  t('html/adv/table[@id=''t2'']/tr/td[@not='''']/text()','','');
  t('html/adv/table[@id=''t2'']/tr/td[@not!='''']/text()','','');
  t('html/adv/table[@id=''t2'']/tr/td[exists(@not)]/text()','','');
  t('html/adv/table[@id=''t2'']/tr/td[exists(@colspan)]/text()','','');
  t('html/adv/table[@id=''t2'']/tr/td[exists(@not)]/blink/text()','','');
  t('html/adv/table[@id=''t2'']/tr/td[exists(@colspan)]/blink/text()','OMG!!','');
  t('html/adv/table/tr/td[exists(@bgcolor)]/text()','2nd col','');
  t('html/adv/table[@id="t2"]/tr/td[exists(@empty)]/text()','C','');
  t('html/adv/table[@id="t2"]/tr/td[@empty='''']/text()','C','');
  t('html/adv/table[@id="t2"]/tr/td[@empty!='''']/text()','','');


                //Regex-Filter
  t('filter(''modern'', ''oder'')',                 'oder',            '');
  t('filter(''regex'', ''.g.'')',                   'ege',             '');
  t('filter(''reg123ex'', ''[0-9]*'')',             '',                '');
  t('filter(''reg123ex'', ''[0-9]+'')',             '123',             '');
  t('filter(''regexREGEX'', ''.G.'')',              'EGE',             '');
  t('filter(''abcdxabcdefx'', ''b[^x]*'')',         'bcd',             '');
  t('filter(''hallo welt'', ''(.*) (.*)'')',        'hallo welt',      '');
  t('filter(''hallo welt'', ''(.*) (.*)'', ''0'')', 'hallo welt',      '');
  t('filter(''hallo welt'', ''(.*) (.*)'', ''1'')', 'hallo',           '');
  t('filter(''hallo welt'', ''(.*) (.*)'', ''2'')', 'welt',            '');

                //Replace
  t('replace("abracadabra", "bra", "*")', 'a*cada*', '');
  t('replace("abracadabra", "a.*a", "*")', '*', '');
  t('replace("abracadabra", "a.*?a", "*")', '*c*bra', '');
  t('replace("abracadabra", "a", "")', 'brcdbr', '');
  t('replace("abracadabra", "a(.)", ''a$1$1'')', 'abbraccaddabbra', '');
  t('replace("abracadabra", ".*?", ''$1'')', 'abracadabra', ''); //in contrast to w3c tests where it causes an error
  t('replace("AAAA", "A+", "b")', 'b', '');
  t('replace("AAAA", "A+?", "b")', 'bbbb', '');
  t('replace("darted", ''^(.*?)d(.*)$'', ''$1c$2'')', 'carted', '');
  t('replace("AAAA", "a+", "b")', 'AAAA', '');
  t('replace("AAAA", "a+", "b", ''i'')', 'b', '');

  t('translate("bar","abc","ABC")', 'BAr', '');
  t('translate("--aaa--","abc-","ABC")', 'AAA', '');
  t('translate("abcdabc", "abc", "AB")', 'ABdAB', '');
  t('translate("abcdabc", "abc", "bca")', 'bcadbca', '');

                //Eval,
  t('''html/text()''', 'html/text()', '');
  t('eval(''html/text()'')', 'test:last text', '');
  t('$eval;', '''abc'' = ''abc''', '');
  t('eval($eval;)', 'true', '');

                //All together
  t('filter(concat(''abc'', ''def''), concat(''[^a'',''d]+'' ))', 'bc','');
  t('concat(''-->'', filter(''miauim'', ''i.*i'') , ''<--'')',   '-->iaui<--','');
  t('filter(''hallo'', ''a'') = ''a''', 'true',                       '');
  t('filter(''hallo'', ''x'') != ''''', 'false',                       '');
  t('filter(html/@attrib1, ''[^ ]+'')', 'FIRST',                            '');
  t('filter(html/@attrib2, ''[^ ]+'')', 'SECOND',                           '');
  t('filter(html/text(), ''[^:]+'')', 'test',                               '');
  t('string-join(tokenize("a,b,c",","), ";")', 'a;b;c',                               '');
                //('filter(''$testvar_t;'', ''$testvar_f;'' == ''true'') == ''true''', 'false',''),
                //('filter(''$testvar_t;'', ''$testvar_t;'' == ''true'') == ''true''', 'true',''),
                //('filter(''$testvar_f;'', ''$testvar_f;'' == ''true'') == ''true''', 'false',''),
                //('filter(''$testvar_f;'', ''$testvar_t;'' == ''true'') == ''true''', 'false','')


  t('inner-xml(a/b)', 'x<t>y<u>++</u></t>z', '<a><aa>aaa</aa><b>x<t>y<u>++</u></t>z</b>233<c>23</c>434<d>434</d></a>');
  t('outer-xml(a/b)', '<b>x<t>y<u>++</u></t>z</b>', '');
  t('a/b/inner-xml()', 'x<t>y<u>++</u></t>z', '');
  t('a/b/outer-xml()', '<b>x<t>y<u>++</u></t>z</b>', '');


                //New tests
  t('', '', '<a><b>Hallo</b><c></c><d>xyz</d><e><f>FFF</f><g>GGG<h>HHH<br/>hhh</h></g></e><e.z>ez</e.z></a>');

                //XPath reading
  t('a/b/text()', 'Hallo', '');
  t('a/c/text()', '', '');
  t('a/d/text()', 'xyz', '');
  t('a//text()', 'Hallo', '');
  t('a/*/text()', 'Hallo', '');
  t('a/g/h/text()', '', '');
  t('a/e/g/h/text()', 'HHH', '');
  t('a/e/./g/././h/text()', 'HHH', '');
  t('a/e/g/h/../text()', 'GGG', '');
  t('a/e/../e/../e/../e/g/h/../text()', 'GGG', '');
  t('a//h/text()', 'HHH', '');
  t('a/e.z/text()', 'ez', '');

  //case (in-)sensitivesnes
  t('', '', '<A att1="att1"><b bat="man" BED="SLEEP">Hallo</b><C at="lol" aTt="LOL"></C></a>');

  t('A/b/text()', 'Hallo', '');
  t('a/b/text()', 'Hallo', '');
  t('a/B/text()', 'Hallo', '');
  t('a/@att1', 'att1', '');
  t('a/@ATT1', 'att1', '');
  t('a/attribute::att1', 'att1', '');
  t('a/attribute::aTt1', 'att1', '');
  t('a//B/@BAT', 'man', '');
  t('a//B/@bed', 'SLEEP', '');
  t('a//B/attribute::bed', 'SLEEP', '');
  t('a/B[@bat=''man'']/text()', 'Hallo', '');
  t('a/B[@BAT=''man'']/text()', 'Hallo', '');
  t('a/B[@bat=''MAN'']/text()', 'Hallo', ''); //comparison is also case-insensitive!
  t('a/B[@bat=''MEN'']/text()', '', '');
  t('a/B[''TRUE'']/text()', 'Hallo', '');
  t('a/B[''true'']/text()', 'Hallo', '');
  t('a/B[''FALSE'']/text()', '', '');
  t('''A''=''a''', 'true', '');
  t('  ''A''  =  ''a''  ', 'true', '');
  t('A/attribute::*', 'att1', '');
  t('A/b/attribute::*', 'man', '');
  t('(A/b/attribute::*)[1]', 'man', '');
  t('(A/b/attribute::*)[2]', 'SLEEP', '');
  t('A/@*', 'att1', '');
  t('A/b/@*', 'man', '');
  t('A/b/@*[1]', 'man', '');
  t('A/b/@*[2]', 'SLEEP', '');
  t('A/b/@*[3]', '', '');

  //attributes without value
  t('', '', '<r><x attrib1>hallo</x><x attrib2>mamu</x><x attrib3 test="test">three</x><x x=y attrib4>four</x><x v="five" attrib5/><x v="six" attrib6/></r>');

  t('r/x[exists(@attrib1)]/text()', 'hallo', '');
  t('r/x[exists(@attrib2)]/text()', 'mamu', '');
  t('r/x[exists(@attrib3)]/text()', 'three', '');
  t('r/x[exists(@attrib4)]/text()', 'four', '');
  t('r/x[@attrib1=""]/text()', 'hallo', '');
  t('r/x[@attrib1!=""]/text()', '', '');
  t('r/x[@attrib1="attrib1"]/text()', '', '');
  t('r/x[@x=''y'']/text()', 'four', '');
  t('r/x[exists(@attrib5)]/@v', 'five', '');
  t('r/x[exists(@attrib6)]/@v', 'six', '');
  t('r/x[exists(@attrib)]/@v', 'hallo', '<r><x   v="hallo"   attrib=   /></r>');
  t('r/x[exists(@attribx)]/@v', '', '<r><x   v="hallo"   attrib=   /></r>');
  t('r/x[exists(@attrib)]/text()', 'mimp', '<r><x   v="hallo"   attrib=   >mimp</x></r>');
  t('r/x[exists(@attribx)]/text()', '', '<r><x   v="hallo"   attrib=   >dimp</x></r>');
  t('r/x[exists(@attrib)]/text()', 'Ximp', '<r><x   v="hallo"   attrib=>Ximp</x></r>');
  t('r/x[exists(@attribx)]/text()', '', '<r><x   v="hallo"   attrib=>dimp</x></r>');
                //strange attributes
  t('r/a/@href', '/home/some/people/use/this!', '<r><a href=/home/some/people/use/this!>...</a></r>');
  t('r/a/@href', '/omg/some/people/use/this!', '<r><a href=/omg/some/people/use/this!/></r>');
  t('r/text()', 'later', '<r><a href=/omg/some/people/use/this!/>later</r>');
  t('r/a/@href', '/omg/some/people/use/this!', '<r><a href=/omg/some/people/use/this!/>later</r>');
  t('r/a[exists(@wtf)]/@href', '/some/people/use/this!', '<r><a href=/some/people/use/this! wtf/></r>');
                //path rules
  t('a/b/c/../../x/text()', '3', '<a><b><x>1</x><c><x>2</x></c></b><x>3</x></a>');
  t('a//(x/text())', '1', '');
  t('a//string(x/text())', '3', '');
  t('a//x/text()', '1', ''); //if this returns 3 it is probably evaluated as a//(x/text()) and not ordered
  t('a//x/string(text())', '1', ''); //if this returns 3 it is probably evaluated as a//(x/text()) and not ordered
  t('a/b/c/../..//x/text()', '1', '');
  t('a/b/./c/../../x/text()', '3', '');
  t('html/body/t[@id="right"]/text()', '123', '<html>A<body>B<t>xy</t>C<t id="right">123</t>D</body>E</html>');
  t('html//t[@id="right"]/text()', '123', '');
  t('html/*/t[@id="right"]/text()', '123', '');
  t('html/t[@id="right"]/text()', '', '');
  t('html/body/t[@id="right"]/text()', '', '<html>A<body>B<x>C<t>xy</t>D<t id="right">123</t>E</x>F</body>G</html>');
  t('html//t[@id="right"]/text()', '123', '');
  t('html/*/t[@id="right"]/text()', '', '');
  t('html/*/*/t[@id="right"]/text()', '123', '');
  t('html/t[@id="right"]/text()', '', '');
  t('html/body/x/t[@id="right"]/text()', '123', '');
  t('html/*/x/t[@id="right"]/text()', '123', '');
  t('html/body/*/t[@id="right"]/text()', '123', '');
  t('html/body/t[@id="right"]/text()', '123', '<html><body><t>xy</t><t id="right">123</t></body></html>');
  t('html//t[@id="right"]/text()', '123', '');
  t('html/*/t[@id="right"]/text()', '123', '');
  t('html/t[@id="right"]/text()', '', '');
  t('html/body/t[@id="right"]/text()', '', '<html><body><x><t>xy</t><t id="right">123</t></x></body></html>');
  t('html//t[@id="right"]/text()', '123', '');
  t('html/*/t[@id="right"]/text()', '', '');
  t('html/*/*/t[@id="right"]/text()', '123', '');
  t('html/t[@id="right"]/text()', '', '');
  t('html/body/x/t[@id="right"]/text()', '123', '');
  t('html/*/x/t[@id="right"]/text()', '123', '');
  t('html/body/*/t[@id="right"]/text()', '123', '');
  t('a//d/text()', '4', '<a>1<b>2<c>3<d>4</d>5</c>6</b>7</a>');
                //TODO: check these: http://www.w3.org/TR/xpath20/#abbrev

                //numbers
  t('1234', '1234', '');
  t('1234e-3', '1.234', '');
  t('1234e-4', '0.1234', '');
  t('-1234', '-1234', '');
  t('-12.34E1', '-123.4', '');
  t('.34E2', '34', '');
  t('-.34E2', '-34', '');
  t('0.34E+3', '340', '');
  t('-42E-1', '-4.2', '');

                //New Comparisons
  t('3<4', 'true', '');
  t('4<4', 'false', '');
  t('-3<3', 'true', '');
  t('3.7<4', 'true', '');
  t('4.00<4', 'false', '');
  t('"maus" <  "maushaus"', 'true', '');
  t('"maus" <  "hausmaus"', 'false', '');
  t('"123" <  "1234"', 'true', '');
  t('"1234" <  "1234"', 'false', '');
  t('"1234" <  "1234.0"', 'true', '');
  t('2 <  "3"', 'true', '');
  t('4 <  "3"', 'false', '');
  t('"2" <  5', 'true', '');
  t('3<=4', 'true', '');
  t('4<=4', 'true', '');
  t('-3<=3', 'true', '');
  t('3<=-3', 'false', '');
  t('"maus"="MAUS"', 'true', '');
  t('"maus"="MAUS4"', 'false', '');
  t('"maus" eq "MAUS"', 'true', '');
  t('"maus" eq "MAUS4"', 'false', '');
  t('"maus"=("MAUS4","abc","mausi")', 'false', '');
  t('"maus"=("MAUS4","abc","maus")', 'true', '');
  t('"maus"<="MAUS"', 'true', '');
  t('"maus">="MAUS"', 'true', '');
  t('"maus"<"MAUS"', 'false', '');
  t('"maus">"MAUS"', 'false', '');
  t('4.00>4', 'false', '');
  t('4.00>=4', 'true', '');
  t('4 eq 7', 'false', '');
  t('4 ne 7', 'true', '');
  t('4 lt 7', 'true', '');
  t('4 lt 4', 'false', '');
  t('4 le 7', 'true', '');
  t('4 gt 7', 'false', '');
  t('4 gt 4', 'false', '');
  t('4 ge 7', 'false', '');
  t('4 ge 4', 'true', '');

                //IEEE special numbers
  t('0e0 div 0e0', 'NaN', '');
  t('1e0 div 0e0', 'INF', '');
  t('-1e0 div 0e0', '-INF', '');

                //comparison+type conversion
  t('5<5.0', 'false', '');
  t('5>5.0', 'false', '');
  t('5=5.0', 'true', '');
  t('5<4.9', 'false', '');
  t('5>=1e-20', 'true', '');
  t('5>=6e-20', 'true', '');
  t('5.00<true()', 'false', '');
  t('5.00<false()', 'false', '');
  t('5.00>true()', 'true', '');
  t('5.00>false()', 'true', '');
  t('1.00>true()', 'false', '');
  t('1.00>false()', 'true', '');
  t('0.00>true()', 'false', '');
  t('0.00>false()', 'false', '');

                //Generic comparisons
  t('(1, 2) = (2, 3)', 'true', '');
  t('(1, 2) != (2, 3)', 'true', '');
  t('(2, 3) = (3, 4)', 'true', '');
  t('(1, 2) = (3, 4)', 'false', '');

                //Binary/unary ops
  t('3-3', '0','');
  t('3+3', '6','');
  t('3--3', '6','');
  t('3---4', '-1','');
  t('3 * 2.5', '7.5','');
  t('3 div 2.0', '1.5','');
  t('3.0 idiv 2.0', '1','');
  t('-3.0 idiv 2.0', '-1','');
  t('3 idiv 2', '1','');
  t('-3 idiv 2', '-1','');
  t('3 idiv -2', '-1','');
  t('-3 idiv -2', '1','');
  t('10 idiv 3', '3','');
  t('9.0 idiv 3', '3','');
  t('-3.5 idiv 3', '-1','');
  t('3.0 idiv 4', '0','');
  t('3.1E1 idiv 6', '5','');
  t('3.1E1 idiv 7', '4','');

  t('3 mod 2', '1','');
  t('-3 mod 2', '-1','');
  t('3 mod -2', '1','');
  t('-3 mod -2', '-1','');
  t('10 mod 3', '1','');
  t('9.0 mod 3', '0','');
  t('-3.5 mod 3', '-0.5','');
  t('3.0 mod 4', '3','');
  t('3.1E1 mod 6', '1','');
  t('3.1E1 mod 7', '3','');
  t('6 mod -2', '0','');
  t('4.5 mod 1.2', '0.9','');
  t('1.23E2 mod 0.6e1', '3','');

  t('3 * 2.0', '6','');
  t('3 = 3.0', 'true','');
  t('3 = + 3.0', 'true','');
  t('3 = - 3.0', 'false','');
  t('3 = ---3.0', 'false','');
  t('3 = --3.0', 'true','');
  t('-3= ---3.0', 'true','');

  t('1 to 3', '1','');
  t('string-join(1 to 3,",")', '1,2,3','');
  t('string-join(3 to 1,",")', '','');
  t('string-join(5 to 5,",")', '5','');
  t('string-join((10, 1 to 4),",")', '10,1,2,3,4','');
  t('string-join((10 to 10),",")', '10','');
  t('string-join((15 to 10),",")', '','');
  t('string-join(reverse(10 to 15),",")', '15,14,13,12,11,10','');


  t('true() and true()', 'true', '');
  t('false() and true()', 'false', '');
  t('false() and false()', 'false', '');
  t('true() or true()', 'true', '');
  t('false() or true()', 'true', '');
  t('false() or false()', 'false', '');

                //Priorities
  t('2*3 + 1', '7', '');
  t('1 + 2*3', '7', '');
  t('(1 + 2)*3', '9', '');
  t('((1 + 2))*3', '9', '');
  t('((1 + 2))*(1+2)', '9', '');
  t('1+((1 + 2))*(1+2)*(2+1)+1', '29', '');
  t('1 + 2 + 3', '6', '');
  t('1 + 2 * 7 + 3', '18', '');
  t('1 + 2 * 7 * 2 + 3', '32', '');
  t('1 + 2 - 4', '-1', '');
  t('1 - 4 + 6', '3', '');
  t('1 - 2 + 3 - 4', '-2', '');
  t('2 - 1 = 1', 'true', '');
  t('1 - 2 = -1', 'true', '');
  t('2 - 1 = 3', 'false', '');
  t('1 - 2 = -3', 'false', '');
  t('3 + 4 = 2 + 5', 'true', '');
  t('3 + 4 = 2 + 4', 'false', '');
  t('3 + 4 = -2 + 9', 'true', '');
  t('3 + 4 = -3 + 9', 'false', '');
  t('3 + 4 = -3 + 9 or 3 = 3', 'true', '');
  t('3 + 4 = -3 + 9 or 3 = 4', 'false', '');
  t('3 + 4 = -3 + 9 or 1+1+1 = 4', 'false', '');
  t('3 + 4 = -3 + 9 or 1+1+1 = 3', 'true', '');
  t('9223372036854775807', '9223372036854775807', '');
  t('-9223372036854775807', '-9223372036854775807', '');
  t('-  9223372036854775808', '-9223372036854775808', '');

                //Constructors
  t('xs:decimal("6.5")', '6.5', '');
  t('xs:string("6.5")', '6.5', '');
  t('xs:string("MEMLEAK5")', 'MEMLEAK5', '');
  t('xs:int("6.5")', '6', '');
  t('xs:boolean("6.5")', 'true', '');
  t('xs:decimal(xs:datetime("1900-01-01"))', '2', '');
  t('type-of(xs:decimal("6.5"))', 'decimal', '');
  t('type-of(xs:string("6.5"))', 'string', '');
  t('type-of(xs:string("MEMLEAK6"))', 'string', '');
  t('type-of(xs:int("6.5"))', 'int', '');
  t('type-of(xs:integer("6.5"))', 'integer', '');
  t('type-of(xs:boolean("6.5"))', 'boolean', '');
  t('type-of(xs:datetime("1800-01-01"))', 'dateTime', '');
  t('xs:decimal("INF")', 'INF', '');
  t('xs:decimal("-INF")', '-INF', '');
  t('xs:decimal("NaN")', 'NaN', '');

                //Functions
                 //Numbers
  t('abs(10.5)', '10.5', '');
  t('abs(-10.5)', '10.5', '');
  t('fn:abs(-10.5)', '10.5', '');
  t('abs(10.5) = 10.5', 'true', '');
  t('ceiling(10.5)', '11', '');
  t('ceiling(-10.5)', '-10', '');
  t('floor(10.5)', '10', '');
  t('floor(-10.5)', '-11', '');
  t('round(2.5)', '3', '');
  t('round(2.4999)', '2', '');
  t('round(-2.5)', '-2', '');
  t('round-half-to-even(0.5)', '0', '');
  t('round-half-to-even(1.5)', '2', '');
  t('round-half-to-even(2.5)', '2', '');
  t('round-half-to-even(3.567812E+3, 2)', '3567.81', '');
  t('round-half-to-even(4.7564E-3, 2)', '0', '');
  t('round-half-to-even(35612.25, -2)', '35600', '');
  t('number("42")', '42', '');
  t('number("")', 'NaN', '');
  t('number(false())', '0', '');
  t('number(true())', '1', '');
  t('number()', '7800', '<a>78<b>0</b>0</a>');
  t('number(())', 'NaN', '');
                 //Types
  t('exists(false())', 'true', '');
  t('exists("")', 'true', '');
  t('exists(@xxxxunknown)', 'false', '');
  t('exists(())', 'false', '');
  t('exists(0)', 'true', '');
  t('type-of(())', 'undefined', '');
  t('type-of(0)', 'integer', '');
  t('type-of(0.0)', 'decimal', '');
  t('type-of("a")', 'string', '');
  t('type-of(parse-datetime("2010-10-10","yyyy-mm-dd"))', 'dateTime', '');
  t('type-of(parse-date("2010-10-10","yyyy-mm-dd"))', 'date', '');
  t('type-of(parse-time("2010-10-10","yyyy-mm-dd"))', 'time', '');
  t('type-of(eval("0"))', 'integer', '');
  t('type-of(eval("0 + 9.0"))', 'decimal', '');

  //Stringfunctions
  t('string()', 'mausxyzx', '<a>maus<b>xyz</b>x</a>');
  t('string()', 'mausxyzx', '');
  t('string(())', '', '');
  t('string(123)', '123', '');
  t('string("123a")', '123a', '');
  t('string-length("Harp not on that string, madam; that is past.")', '45', '');
  t('string-length(())', '0', '');
  t('string-length()', '8', ''); //mausxyzx
  t('concat("A", "-2")', 'A-2', '');
  t('concat("A", 2)', 'A2', '');
  t('concat("A", 2+3)', 'A5', '');
  t('concat("A", 2+3, 7)', 'A57', '');
  t('concat("A", 2+3, -7)', 'A5-7', '');
  t('string-join((''Now'', ''is'', ''the'', ''time'', ''...''), '' '')', 'Now is the time ...', '');
  t('string-join((''Blow, '', ''blow, '', ''thou '', ''winter '', ''wind!''), '''')', 'Blow, blow, thou winter wind!', '');
  t('string-join((), ''separator'')', '', '');
  t('string-join(("a","b","c"), '':'')', 'a:b:c', '');
  t('string-join(("a","b","c",("d","e"), (("f"))), '':'')', 'a:b:c:d:e:f', '');
  t('codepoints-to-string(65)', 'A', '');
  t('codepoints-to-string((65,66,67,68))', 'ABCD', '');
  t('string-to-codepoints("ABCD")', '65', '');
  t('string-join(string-to-codepoints("ABCD"),",")', '65,66,67,68', '');
  t('codepoints-to-string((2309, 2358, 2378, 2325))', 'अशॊक', ''); //if these tests fail, but those above work, fpc probably compiled the file with the wrong encoding (must be utf8);
  t('string-to-codepoints("Thérèse")', '84', '');
  t('string-join(string-to-codepoints("Thérèse"),",")', '84,104,233,114,232,115,101', '');
  t('substring("motor car", 6)', ' car', '');
  t('substring("metadata", 4, 3)', 'ada', '');
  t('substring("12345", 1.5, 2.6)', '234', '');
  t('substring("12345", 0, 3)', '12', '');
  t('substring("12345", 5, -3)', '', '');
  t('substring("12345", -3, 5)', '1', '');
  t('substring("12345", 0 div 0e0, 3)', '', '');
  t('substring("12345", 1, 0 div 0e0)', '', '');
  t('substring((), 1, 3)', '', '');
  t('substring("12345", -42, 1 div 0e0)', '12345', '');
  t('substring("12345", -1 div 0e0, 1 div 0e0)', '', '');
  t('lower-case("ABc!D")', 'abc!d', '');
  t('upper-case("abCd0")', 'ABCD0', '');
  t('contains( "tattoo", "t")', 'true', '');
  t('contains( "tattoo", "ttt")', 'false', '');
  t('contains( "tattoo", "tT")', 'true', '');
  t('contains( "",  ())', 'true', '');
  t('starts-with("tattoo", "tattoo")', 'true', '');
  t('starts-with("tattoo", "tattoox")', 'false', '');
  t('starts-with("tattoo", "tat")', 'true', '');
  t('starts-with("tattoo", "att")', 'false', '');
  t('starts-with("tattoo", "TAT")', 'true', '');
  t('starts-with((), ())', 'true', '');
  t('ends-with("tattoo", "tattoo")', 'true', '');
  t('ends-with("tattoo", "tattoox")', 'false', '');
  t('ends-with("tattoo", "too")', 'true', '');
  t('ends-with("tattoo", "atto")', 'false', '');
  t('ends-with("tattoo", "TTOO")', 'true', '');
  t('ends-with((), ())', 'true', '');
  t('substring-before("tattoo", "attoo")', 't', '');
  t('substring-before("tattoo", "o")', 'tatt', '');
  t('substring-before("tattoo", "OO")', 'tatt', '');
  t('substring-before("tattoo", "tatto")', '', '');
  t('substring-before((), ())', '', '');
  t('substring-after("tattoo", "tat")', 'too', '');
  t('substring-after("tattoo", "tatto")', 'o', '');
  t('substring-after("tattoo", "tattoo")', '', '');
  t('substring-after("tattoo", "T")', 'attoo', '');
  t('substring-after((), ())', '', '');
  t('matches("abracadabra", "bra")', 'true','');
  t('matches("abracadabra", ''^a.*a$'')', 'true', '');
  t('matches("abracadabra", "^bra")', 'false', '');
  t('poem/text()', 'Kaum hat dies der Hahn gesehen,'#13#10'Fängt er auch schon an zu krähen:'#13#10'«Kikeriki! Kikikerikih!!»'#13#10'Tak, tak, tak! - da kommen sie.', '<poem author="Wilhelm Busch">'#13#10'Kaum hat dies der Hahn gesehen,'#13#10'Fängt er auch schon an zu krähen:'#13#10'«Kikeriki! Kikikerikih!!»'#13#10'Tak, tak, tak! - da kommen sie.'#13#10'</poem>');
  t('./text()', '', ''); //above /\, white space trimmed
  t('text()', '', '');
  t('.//text()', 'Kaum hat dies der Hahn gesehen,'#13#10'Fängt er auch schon an zu krähen:'#13#10'«Kikeriki! Kikikerikih!!»'#13#10'Tak, tak, tak! - da kommen sie.', '');
  t('matches(poem/text(), "Kaum.*krähen", "")', 'false', '');
  t('matches(poem/text(), "Kaum.*krähen")', 'false', '');
  t('matches(poem/text(), "Kaum.*krähen", "s")', 'true', '');
  t('matches(poem/text(), ''^Kaum.*gesehen,$'', "m")', 'true', '');
  t('matches(poem/text(), ''^Kaum.*gesehen,$'', "")', 'false', '');
  t('matches(poem/text(), ''^Kaum.*gesehen,$'')', 'false', '');
  t('matches(poem/text(), "kiki", "")', 'false', '');
  t('matches(poem/text(), "kiki", "i")', 'true', '');
  t('normalize-space("  hallo   ")', 'hallo', '');
  t('normalize-space("  ha'#9#13#10'llo   ")', 'ha llo', '');
  t('normalize-space("  ha'#9#13#10'l'#9' '#9'lo   ")', 'ha l lo', '');
                //Boolean
  t('boolean(0)', 'false', '');
  t('boolean("0")', 'false', '');
  t('boolean("1")', 'true', '');
  t('boolean("")', 'false', '');
  t('boolean(1)', 'true', '');
  t('boolean("false")', 'false', '');
  t('boolean("true")', 'true', '');
  t('boolean(false())', 'false', '');
  t('boolean(true())', 'true', '');
  t('false()', 'false', '');
  t('true()', 'true', '');
  t('not(false())', 'true', '');
  t('not(true())', 'false', '');
  t('not("false")', 'true', '');
  t('not("true")', 'false', '');
  t('not("falses")', 'false', '');
                //Dates
  t('xs:double(parse-date("2010-10-9", "yyyy-mm-d"))', '40460', '');
  t('xs:double(parse-date("2010-10-08", "yyyy-mm-d"))', '40459', '');
  t('xs:double(parse-date("1899-Dec-31", "yyyy-mmm-d"))', '1', '');
  t('xs:double(parse-date("1899-Dec-29", "yyyy-mmm-d"))', '-1', '');
  t('year-from-datetime(parse-date("1800-09-07", "yyyy-mm-dd"))', '1800', '');
  t('year-from-date(parse-date("1800-09-07", "yyyy-mm-dd"))', '1800', '');
  t('year-from-datetime(parse-date(">>2012<<01:01", ">>yyyy<<mm:dd"))', '2012', '');
  t('year-from-datetime(parse-date(">>1700<<01:01", ">>yyyy<<mm:dd"))', '1700', '');
  t('year-from-datetime(parse-date(">>05<<01:01", ">>yy<<mm:dd"))', '2005', '');
  t('year-from-datetime(parse-date(">>90<<01:01", ">>yy<<mm:dd"))', '1990', '');
  t('year-from-datetime(parse-date(">>89<<01:01", ">>yy<<mm:dd"))', '2089', '');
  t('month-from-datetime(parse-date("1899-Dec-31", "yyyy-mmm-d")) ', '12', '');
  t('month-from-datetime(parse-date("1899-Jul-31", "yyyy-mmm-d")) ', '7', '');
  t('day-from-datetime(parse-date("1899-Jul-31", "yyyy-mmm-d")) ', '31', '');
  t('parse-date("1899-Dec-31", "yyyy-mmm-d") - parse-date("1899-Dec-29", "yyyy-mmm-d")', 'P2D', '');
                //Sequences
  t('index-of ((10, 20, 30, 40), 35)', '', '');
  t('index-of ((10, 20, 30, 30, 10), 20)', '2', '');
  t('index-of ((10, 20, 30, 30, 20, 10), 20)', '2', '');
  t('string-join(index-of ((10, 20, 30, 30, 10), 20), ",")', '2', '');
  t('string-join(index-of ((10, 20, 30, 30, 20, 10), 20), ",")', '2,5', '');
  t('string-join(index-of (("a", "sport", "and", "a", "pastime"), "a"), ",")', '1,4', '');
  t('("MEMLEAKTEST1", "MEMLEAKTEST2")', 'MEMLEAKTEST1', '');
  t('string-join(("MEMLEAKTEST3", "MEMLEAKTEST4"), "-")', 'MEMLEAKTEST3-MEMLEAKTEST4', '');
  t('empty(())', 'true', '');
  t('empty((4))', 'false', '');
  t('empty((false()))', 'false', '');
  t('empty((true(),1,2,3))', 'false', '');
  t('distinct-values((1, 2.0, 3, 2))', '1', '');
  t('string-join(distinct-values((1, 2.0, 3, 2)),",")', '1,2,3', '');
  t('string-join(insert-before(("a", "b", "c"), 0, "z"), ",")', 'z,a,b,c', '');
  t('string-join(insert-before(("a", "b", "c"), 1, "z"), ",")', 'z,a,b,c', '');
  t('string-join(insert-before(("a", "b", "c"), 2, "z"), ",")', 'a,z,b,c', '');
  t('string-join(insert-before(("a", "b", "c"), 3, "z"), ",")', 'a,b,z,c', '');
  t('string-join(insert-before(("a", "b", "c"), 4, "z"), ",")', 'a,b,c,z', '');
  t('string-join(insert-before(("a", "b", "c"), 5, "z"), ",")', 'a,b,c,z', '');
  t('string-join(insert-before(("a", "b", "c"), 0, "z"), ",")', 'z,a,b,c', '');
  t('string-join(insert-before(("a", "b", "c"), 1, ("x","y","z")), ",")', 'x,y,z,a,b,c', '');
  t('string-join(insert-before(("a", "b", "c"), 2, ("x","y","z")), ",")', 'a,x,y,z,b,c', '');
  t('string-join(insert-before(("a", "b", "c"), 3, ("x","y","z")), ",")', 'a,b,x,y,z,c', '');
  t('string-join(insert-before(("a", "b", "c"), 4, ("x","y","z")), ",")', 'a,b,c,x,y,z', '');
  t('string-join(insert-before(("a", "b", "c"), 5, ("x","y","z")), ",")', 'a,b,c,x,y,z', '');
  t('string-join(remove(("a", "b", "c"), 0), ",")', 'a,b,c', '');
  t('string-join(remove(("a", "b", "c"), 1), ",")', 'b,c', '');
  t('string-join(remove(("a", "b", "c"), 6), ",")', 'a,b,c', '');
  t('string-join(remove((), 3), ",")', '', '');
  t('string-join(remove("a", 3), ",")', 'a', '');
  t('string-join(remove("a", 1), ",")', '', '');
  t('string-join(remove("a", 0), ",")', 'a', '');
  t('string-join(reverse(("c","b","a")), ",")', 'a,b,c', '');
  t('string-join(reverse(("hello")), ",")', 'hello', '');
  t('string-join(reverse(()), ",")', '', '');
  t('string-join(subsequence((1,2,3,4,5), 4), ",")', '4,5', '');
  t('subsequence((), 1)', '', '');
  t('subsequence((), 1, 2)', '', '');
  t('string-join(subsequence((1,2,3,4,5), 3, 2), ",")', '3,4', '');
  t('string-join(unordered((1,2,3,4,5)), ",")', '1,2,3,4,5', '');
  t('deep-equal(1, 2)', 'false', '');
  t('deep-equal(1, 1)', 'true', '');
  t('deep-equal((1), ())', 'false', '');
  t('deep-equal((1), (1))', 'true', '');
  t('deep-equal((1), (1,1))', 'false', '');
  t('deep-equal((1), ("1"))', 'true', '');
  t('deep-equal((1,1), (1))', 'false', '');
  t('deep-equal((1,1), (1,1.0))', 'true', '');
  t('deep-equal((1,2,3,4), (1,2,3,4))', 'true', '');
  t('deep-equal((1,2,3,4), (1,2,3))', 'false', '');
  t('deep-equal(("A","B"), ("a","b"))', 'true', '');
  t('deep-equal(("A","B"), ("a","bc"))', 'false', '');
  t('deep-equal(("A","B", ("c")), ("a","b", "c"))', 'true', '');
  t('count(())', '0', '');
  t('count((10))', '1', '');
  t('count((10,2,"abc","def",17.0))', '5', '');
  t('avg((1,2,3))', '2', '');
  t('avg((1,2,3,4))', '2.5', '');
  t('avg((3,4,5))', '4', '');
  t('avg(())', '', '');
  t('avg((xs:decimal(''INF''), xs:decimal(''-INF'')))', 'NaN', '');
  t('avg((3,4,5, xs:decimal(''NaN'')))', 'NaN', '');
  t('max((1,2,3))', '3', '');
  t('max((3,4,5))', '5', '');
  t('max((1,xs:decimal("NaN"),3))', 'NaN', '');
  t('type-of(max((3,4,5)))', 'integer', '');
  t('max((5, 5.0e0))', '5', '');

  t('max((3,4,"Zero"))', 'Zero', ''); //don't follow xpath
  t('max((current-date(), parse-date("2001-01-01","yyyy-mm-dd"))) = current-date()', 'true', '');
  t('max((current-date(), parse-date("9001-01-01","yyyy-mm-dd"))) = current-date()', 'false', '');
  t('max(("a", "b", "c"))', 'c', '');
  t('max((1,2,3,4))', '4', '');
  t('max((1,25.0,-3,4))', '25', '');
  t('max((1,"5",3,4))', '5', '');
  t('max((1,"2",3,4))', '4', '');
  t('max(("10haus", "100haus", "2haus", "099haus"))', '100haus', '');
  t('min((1,2,3))', '1', '');
  t('min((1,xs:decimal("NaN"),3))', 'NaN', '');
  t('min((3,4,5))', '3', '');
  t('type-of(min((3,4,5)))', 'integer', '');
  t('min((5,5.0))', '5', '');
  t('type-of(min((5,5.0)))', 'decimal', '');
  t('min((3,4,"Zero"))', '3', ''); //don't follow
  t('min((current-date(), parse-date("3001-01-01","yyyy-mm-dd"))) = current-date()', 'true', '');
  t('min((current-date(), parse-date("1901-01-01","yyyy-mm-dd"))) = current-date()', 'false', '');
  t('min((-0.0,0.0))', '0', '');
  t('type-of(min((-0.0,0.0)))', 'decimal', '');
  t('min((1,2,3,4))', '1', '');
  t('min((1,25.0,-3,4))', '-3', '');
  t('min((1,"5",3,4))', '1', '');
  t('min((1,"2",3,4))', '1', '');
  t('min(("10haus", "100haus", "2haus", "099haus"))', '2haus', '');
  t('min(("a", "b", "c"))', 'a', '');
  t('sum((3,4,5))', '12', '');
  t('sum(())', '0', '');
  t('sum((),())', '', '');
  t('sum((3,xs:decimal("NaN"),5))', 'NaN', '');

  t('(1,2,3)[true()]', '1', '');
  t('(1,2,3)[false()]', '', '');
  t('string-join((1,2,3)[true()], ",")', '1,2,3', '');
  t('string-join((1,2,3)[false()], ",")', '', '');
  t('(4,5,6)[1]', '4', '');
  t('(4,5,6)[2]', '5', '');
  t('(4,5,6)[3]', '6', '');
  t('("a","bc","de")[2]', 'bc', '');
  t('string-join((4,5,6)[1], ",")', '4', '');
  t('string-join((4,5,6)[2], ",")', '5', '');
  t('string-join((4,5,6)[3], ",")', '6', '');
  t('string-join((4,5,6)[true()][1], ",")', '4', '');
  t('string-join((4,5,6)[true()][true()][true()][true()][true()][1], ",")', '4', '');
  t('(4,5,6)[string() = ''5'']', '5', '');
  t('string-join((4,5,6)[string()="5"], ",")', '5', '');
  t('string-join((1 to 100)[number() eq 15 or string() = "23"], ",")', '15,23', '');
  t('string-join((1 to 100)[number() mod 5 eq 0], ",")', '5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,100', '');
  t('string-join((21 to 29)[5],",")', '25', '');
  t('string-join((21 to 29)[5],",")', '25', '');
  t('string-join((21 to 29)[number() gt 24][2],",")', '26', '');
  t('string-join(("hallo","mast","welt","test","tast","ast")[contains(string(),"as")], ",")', 'mast,tast,ast', '');
  t('string-join( (4,5) [.=4] , ",")', '4', '');
  t('string-join( ( (4,5) [.=4] ) , ",")', '4', '');
  t('string-join( ( ((4,5)) [(.=4)] ) , ",")', '4', '');
  t('string-join( (((( ((4,5)) [(.=4)] )))) , ",")', '4', '');
  t('string-join((1 to 100)[. mod 5 eq 0],",")', '5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,100', '');
  t('(string-join(((1 to 100)[. mod 5 eq 0]),","))', '5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,100', '');
  t('string-join(((1 to 5)[3] to (3 to 7)[3]),",")', '3,4,5', '');
  t('string-join((4,5,6)[.=(5,6)], ",")', '5,6', '');
  t('count((98.5, 98.3, 98.9))', '3', '');
  t('count((98.5, 98.3, 98.9)[.>100])', '0', '');
  t('count((98.5, 98.3, 98.9)[.>98.5])', '1', '');
  t('sum((1 to 100)[.<0], 0)', '0', '');
  t('sum((1 to 100)[.<0], "aber")', 'aber', '');
  t('sum((1 to 100)[.<10], "abc")', '45', '');
  t('string-join((101 to 120)[position() = 4], ",")', '104', '');
  t('string-join((101 to 120)[position() = last()], ",")', '120', '');
  t('string-join((101 to 120)[position() = last() - 2], ",")', '118', '');
  t('string-join((101 to 120)[position() >= 4 and position() < 10], ",")', '104,105,106,107,108,109', '');
  t('string-join((101 to 120)[position() >= 4 and position() < 10][position()=last()], ",")', '109', '');
  t('string-join((101 to 120)[position() >= 4 and position() < 10][position()=3], ",")', '106', '');
  t('string-join((101 to 120)[position() >= 4 and position() < 10][4], ",")', '107', '');

                //Axis tests
  t('','','<a><b>b1<c>c1</c><c>c2</c><c>c3</c><c>c4</c></b><b>b2</b>al</a>');

                //Iterator
  t('a/b/text()', 'b1', '');
  t('a/b/c/text()', 'c1', '');
  t('a/b/c[text()="c2"]/text()', 'c2', '');
  t('a/b/c[.="c3"]/text()', 'c3', '');
  t('a/b/c[1]/text()', 'c1', '');
  t('a/b/c[2]/text()', 'c2', '');
  t('a/b/c[position() = 2]/text()', 'c2', '');
  t('a/b/c[.="c2" or .="c3"]/text()', 'c2', '');

                //Full sequence
  t('a/b/c[.="c2" or .="c3"][2]/text()', 'c3', '');
  t('a/b/c[last()]/text()', 'c4', '');
  t('a[true()]/b[true()][true()]/c[.="c2" or .="c3"][2]/text()', 'c3', '');
  t('string-join(a/b/c[.="c2" or .="c3"]/text(),",")', 'c2,c3', '');
  t('string-join(a[true()]/b[true()][true()]/c[.="c2" or .="c3"]/text(), ",")', 'c2,c3', '');
  t('string-join(a[true()]  [ 1 ]   /   b[true()] [true(      )]/c[.=("c2","c3")]/text(), ",")', 'c2,c3', '');
  t('string-join(a/b/c/text(), ",")', 'c1,c2,c3,c4', '');
  t('string-join(a/b/text(), ",")', 'b1,b2', '');


  t('','','<a><b>b1<c>c1</c><c>c2</c><c>c3</c><c>c4</c></b>'+
             '<b>b2<c>cx1</c><c>cx2<c>CC1</c></c></b>'+ 'al' +
             '<d>d1</d>'+'<d>d2</d>'+'<d>d3<e>dxe1</e></d>'+'<f>f1</f>'+'<f>f2</f>'+
           '</a>');

  t('string-join(a/b/c/text(), ",")', 'c1,c2,c3,c4,cx1,cx2', '');
  t('string-join(a/b/c[2]/text(), ",")', 'c2,cx2', '');
  t('string-join(a/b/c[position()=(2,3)]/text(), ",")', 'c2,c3,cx2', '');
  t('string-join(a/b/c/c/text(), ",")', 'CC1', '');
  t('string-join(a/b//c/text(), ",")', 'c1,c2,c3,c4,cx1,cx2,CC1', '');
  t('string-join(a//b/c[2]/text(), ",")', 'c2,cx2', '');
  t('string-join(a/b//c[2]/text(), ",")', 'c2,cx2', '');
  t('string-join(a/b//c[position()=(2,3)]/text(), ",")', 'c2,c3,cx2', '');
  t('string-join(a/b//c[7]/text(), ",")', '', '');
  t('string-join(a//c[1]/text(), ",")', 'c1,cx1,CC1', '');
  t('string-join(a/b//c[1]/text(), ",")', 'c1,cx1,CC1', '');
  t('string-join(a/b//c[2]/text(), ",")', 'c2,cx2', '');
  t('string-join(a/b//c[position()=last()]/text(), ",")', 'c4,cx2,CC1', '');
  t('string-join(a/*/text(), ",")', 'b1,b2,d1,d2,d3,f1,f2', '');
  t('string-join(a/node()/text(), ",")', 'b1,b2,d1,d2,d3,f1,f2', '');
  t('string-join(a/b, ",")', 'b1c1c2c3c4,b2cx1cx2CC1', '');
  t('string-join(a/b/c, ",")', 'c1,c2,c3,c4,cx1,cx2CC1', '');
  t('string-join(a/*/c, ",")', 'c1,c2,c3,c4,cx1,cx2CC1', '');
  t('string-join(a/node()/c, ",")', 'c1,c2,c3,c4,cx1,cx2CC1', '');
  t('string-join(a//c, ",")', 'c1,c2,c3,c4,cx1,cx2CC1,CC1', '');
  t('string-join(a/d, ",")', 'd1,d2,d3dxe1', '');
  t('string-join(a/d/text(), ",")', 'd1,d2,d3', '');
  t('string-join(a/f, ",")', 'f1,f2', '');
  t('string-join(a/f/node(), ",")', 'f1,f2', '');
  t('string-join(a/(d,f), ",")', 'd1,d2,d3dxe1,f1,f2', '');
  t('string-join(a/(d,f)/text(), ",")', 'd1,d2,d3,f1,f2', '');
  t('string-join((a/b) / (c/c), ",")', 'CC1', '');
  t('string-join(a/b[2]/c[1]/c[1], ",")', '', '');
  t('string-join(a/b[2]/c[2]/c[1], ",")', 'CC1', '');
                //concattenate,union,intersect,except
  t('string-join((a/b, a/f), ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f1,f2', '');
  t('string-join((a/f, a/b), ",")', 'f1,f2,b1c1c2c3c4,b2cx1cx2CC1', '');
  t('string-join((a/f, a/b, a/f), ",")', 'f1,f2,b1c1c2c3c4,b2cx1cx2CC1,f1,f2', '');
  t('string-join(a/b | a/f, ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f1,f2', '');
  t('string-join(a/f | a/b, ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f1,f2', '');
  t('string-join(a/b union a/f, ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f1,f2', '');
  t('string-join(a/f union a/b, ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f1,f2', '');
  t('string-join(a/b | a/f | a/b, ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f1,f2', '');
  t('string-join(a/f | a/b | a/f |a/b, ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f1,f2', '');
  t('string-join(a/b[1] | a/f, ",")', 'b1c1c2c3c4,f1,f2', '');
  t('string-join(a/b[1] | a/f[2], ",")', 'b1c1c2c3c4,f2', '');
  t('string-join(a/b | a/f[2], ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f2', '');
  t('string-join((a/b, a/d) / (e, c/c), ",")', 'CC1,dxe1', '');
  t('string-join((a/b|a/d) / (e, c/c), ",")', 'CC1,dxe1', '');
  t('string-join((a/b, a/d) / (e|c/c), ",")', 'CC1,dxe1', '');
  t('string-join((a/b|a/d) / (e|c/c), ",")', 'CC1,dxe1', '');
  t('string-join(a//c except a/b/c/c , ",")', 'c1,c2,c3,c4,cx1,cx2CC1', '');
  t('string-join(a//c except a/b/c/c/text() , ",")', 'c1,c2,c3,c4,cx1,cx2CC1,CC1', '');
  t('string-join(a//c/text() except a/b/c/c/text() , ",")', 'c1,c2,c3,c4,cx1,cx2', '');
  t('string-join(a//c/text() except a/b/c/c , ",")', 'c1,c2,c3,c4,cx1,cx2,CC1', '');
  t('string-join(a//c except a//c/c , ",")', 'c1,c2,c3,c4,cx1,cx2CC1', '');
  t('string-join(a//c except a//c/c/text() , ",")', 'c1,c2,c3,c4,cx1,cx2CC1,CC1', '');
  t('string-join(a//c/text() except a//c/c/text() , ",")', 'c1,c2,c3,c4,cx1,cx2', '');
  t('string-join(a//c/text() except a//c/c , ",")', 'c1,c2,c3,c4,cx1,cx2,CC1', '');
  t('string-join(a//c intersect a/b/c/c , ",")', 'CC1', '');
  t('string-join(a//c intersect a/b/c/c/text() , ",")', '', '');
  t('string-join(a//c/text() intersect a/b/c/c/text() , ",")', 'CC1', '');
  t('string-join(a//c/text() intersect a/b/c/c , ",")', '', '');
  t('string-join(a//c intersect a//c/c , ",")', 'CC1', '');
  t('string-join(a//c intersect a//c/c/text() , ",")', '', '');
  t('string-join(a//c/text() intersect a//c/c/text() , ",")', 'CC1', '');
  t('string-join(a//c/text() intersect a//c/c , ",")', '', '');
  t('string-join((a/f | a/b) intersect a/b, ",")', 'b1c1c2c3c4,b2cx1cx2CC1', '');
  t('string-join((a/f | a/b) intersect a/f, ",")', 'f1,f2', '');
  t('string-join((a/f | a/b) intersect a/b[2], ",")', 'b2cx1cx2CC1', '');
  t('string-join((a/f | a/b) intersect a/f[2], ",")', 'f2', '');
  t('string-join((a/f | a/b) intersect (a/b | a/f), ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f1,f2', '');
  t('string-join((a/f | a/b) intersect (a/f | a/d), ",")', 'f1,f2', '');
  t('string-join((a/f | a/b) intersect (a/d), ",")', '', '');
  t('string-join((a/f | a/b) intersect (), ",")', '', '');
  t('string-join(() intersect (a/f | a/d), ",")', '', '');
  t('string-join((a/f | a/b) except a/b, ",")', 'f1,f2', '');
  t('string-join((a/f | a/b) except a/f, ",")', 'b1c1c2c3c4,b2cx1cx2CC1', '');
  t('string-join((a/f | a/b) except a/b[2], ",")', 'b1c1c2c3c4,f1,f2', '');
  t('string-join((a/f | a/b) except a/f[2], ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f1', '');
  t('string-join((a/f | a/b) except (a/b | a/f), ",")', '', '');
  t('string-join((a/f | a/b) except (a/f | a/d), ",")', 'b1c1c2c3c4,b2cx1cx2CC1', '');
  t('string-join((a/f | a/b) except (a/d), ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f1,f2', '');
  t('string-join((a/f | a/b) except (), ",")', 'b1c1c2c3c4,b2cx1cx2CC1,f1,f2', '');
  t('string-join(() except (a/f | a/d), ",")', '', '');
                //is,<<,>>
  t('a/b[1] is a/b[2]', 'false', '');
  t('a/b[2] is a/b[1]', 'false', '');
  t('a/b[1] is a/b[1]', 'true', '');
  t('a/b[1]/c[1] is a/b/c/c', 'false', '');
  t('a/b[2]/c[1] is a/b/c/c', 'false', '');
  t('a/b[2]/c[2]/c[1] is a/b/c/c', 'true', '');
  t('a/b[1] << a/b[2]', 'true', '');
  t('a/b[2] << a/b[1]', 'false', '');
  t('a/b[1] << a/b[1]', 'false', '');
  t('a/b[1]/c[1] << a/b/c/c', 'true', '');
  t('a/b[2]/c[1] << a/b/c/c', 'true', '');
  t('a/b[2]/c[2]/c[1] << a/b/c/c', 'false', '');
  t('a/b[1] >> a/b[2]', 'false', '');
  t('a/b[2] >> a/b[1]', 'true', '');
  t('a/b[1] >> a/b[1]', 'false', '');
  t('a/d[1] >> a/b[1]', 'true', '');
  t('a/b[1]/c[1] >> a/b/c/c', 'false', '');
  t('a/b[2]/c[1] >> a/b/c/c', 'false', '');
  t('a/b[2]/c[2]/c[1] >> a/b/c/c', 'false', '');
                //axes
  t('a/child::b', 'b1c1c2c3c4', '');
  t('child::a/child::b', 'b1c1c2c3c4', '');
  t('child::a/child::b/child::text()', 'b1', '');
  t('string-join(a/child::b,",")', 'b1c1c2c3c4,b2cx1cx2CC1', '');
  t('string-join(child::a/child::b,",")', 'b1c1c2c3c4,b2cx1cx2CC1', '');
  t('string-join(child::a/child::b/child::text(),",")', 'b1,b2', '');
  t('string-join((child::a/child::b)[2],",")', 'b2cx1cx2CC1', '');
  t('string-join((child::a/child::b/child::text())[1],",")', 'b1', '');
  t('node-name((child::a/child::b)[1])', 'b', '');
  t('node-name((child::a/child::b/child::text())[1])', '', '');
  t('node-name((child::a/child::b/child::text()/..)[1])', 'b', '');
  t('node-name((child::a/child::b/child::text()/../..)[1])', 'a', '');
  t('string-join(a/self::a/self::a/self::a/child::b,",")', 'b1c1c2c3c4,b2cx1cx2CC1', '');
  t('string-join(a/self::a//text(),",")', 'b1,c1,c2,c3,c4,b2,cx1,cx2,CC1,al,d1,d2,d3,dxe1,f1,f2', '');
  t('string-join(a/self::b//text(),",")', '', '');
  t('string-join(a/child::b/parent::a/child::b/text(),",")', 'b1,b2', '');
  t('string-join(a/child::b/parent::x/child::b/text(),",")', '', '');
  t('string-join(a/child::b[1]/following::c,",")', 'cx1,cx2CC1,CC1', '');
  t('string-join(a/child::b/following::c,",")', 'cx1,cx2CC1,CC1', '');
  t('string-join(a/descendant::c/text(),",")', 'c1,c2,c3,c4,cx1,cx2,CC1', '');
  t('string-join(a/descendant-or-self::c/text(),",")', 'c1,c2,c3,c4,cx1,cx2,CC1', '');
  t('string-join(a/child::c/descendant::c/text(),",")', '', '');
  t('string-join(a/child::c/descendant-or-self::c/text(),",")', '', '');
  t('string-join(a/b/child::c/descendant::c/text(),",")', 'CC1', '');
  t('string-join(a/b/child::c/descendant-or-self::c/text(),",")', 'c1,c2,c3,c4,cx1,cx2,CC1', '');
  t('string-join(a/b/following::d/text(),",")', 'd1,d2,d3', '');
  t('string-join(a/b/following-sibling::d/text(),",")', 'd1,d2,d3', '');
  t('string-join(a/b/c/following::d/text(),",")', 'd1,d2,d3', '');
  t('string-join(a/b/c/following-sibling::d/text(),",")', '', '');
  t('string-join(a/b/c/c/ancestor::c/text(),",")', 'cx2', '');
  t('string-join(a/b/c/c/ancestor::b/text(),",")', 'b2', '');
  t('string-join(a/b/c/c/ancestor::a/text(),",")', 'al', '');
  t('string-join(a/b/c/c/ancestor::*/text(),",")', 'b2,cx2,al', '');
  t('string-join(a/b/c/c/ancestor-or-self::*/text(),",")', 'b2,cx2,CC1,al', '');
  t('string-join(a/f/ancestor-or-self::*/text(),",")', 'al,f1,f2', '');
  t('string-join(a/f/ancestor::*/text(),",")', 'al', '');
  t('string-join(a/f/preceding-sibling::*/text(),",")', 'b1,b2,d1,d2,d3,f1', '');
  t('string-join(a/f/preceding::*/text(),",")', 'b1,c1,c2,c3,c4,b2,cx1,cx2,CC1,d1,d2,d3,dxe1,f1', '');
  t('string-join(a/b/c/c/preceding::*/text(),",")', 'b1,c1,c2,c3,c4,cx1', '');



                //todo ,('string-join(a/(d,f)/../text(), ",")', '', '')
               //examples taken from the xpath standard
  t('','','<para>p1</para>' + '<para type="warning">p2</para>' + '<rd>texti</rd>'+'<para type="warning">p3</para>'+'<x>XX</x>'+'<para type="warning">p4</para>'+'<npara>np<para>np1</para><para>np2</para></npara>'+
   '<chapter><ti></ti><div><para>cdp1</para><para>cdp2</para></div></chapter>'+'<b>BB</b>'+'<rd>ltext</rd>'+'<chapter><title>Introduction</title><div><para>CDP1</para><para>CDP2</para></div></chapter>');
  t('string-join(child::para,",")', 'p1,p2,p3,p4', '');
  t('string-join(child::*,",")', 'p1,p2,texti,p3,XX,p4,npnp1np2,cdp1cdp2,BB,ltext,IntroductionCDP1CDP2', '');
  t('string-join(child::text(),",")', '', '');
  t('string-join(rd/child::text(),",")', 'texti,ltext', '');
  t('string-join(child::node(),",")', 'p1,p2,texti,p3,XX,p4,npnp1np2,cdp1cdp2,BB,ltext,IntroductionCDP1CDP2', '');
  t('string-join(descendant::para,",")', 'p1,p2,p3,p4,np1,np2,cdp1,cdp2,CDP1,CDP2', '');
  t('string-join(chapter/div/para/ancestor::div,",")', 'cdp1cdp2,CDP1CDP2', '');
  t('string-join(chapter/div/ancestor::div,",")', '', '');
  t('chapter/div/para/ancestor-or-self::div', 'cdp1cdp2', '');
  t('string-join(chapter/div/para/ancestor-or-self::div,",")', 'cdp1cdp2,CDP1CDP2', '');
  t('string-join(chapter/div/ancestor-or-self::div,",")', 'cdp1cdp2,CDP1CDP2', '');
  t('string-join(chapter/ancestor-or-self::div,",")', '', '');
  t('string-join(descendant-or-self::para,",")', 'p1,p2,p3,p4,np1,np2,cdp1,cdp2,CDP1,CDP2', '');
  t('string-join(para/descendant-or-self::para,",")', 'p1,p2,p3,p4', '');
  t('string-join(para/descendant::para,",")', '', '');
  t('string-join(para/self::para,",")', 'p1,p2,p3,p4', '');
  t('string-join(self::para,",")', '', '');
  t('string-join(child::chapter/descendant::para ,",")', 'cdp1,cdp2,CDP1,CDP2', '');
  t('string-join(child::*/child::para ,",")', 'np1,np2', '');
  t('string-join(npara/child::*,",")', 'np1,np2', '');
  t('string-join(npara/child::*/child::para ,",")', '', '');
  t('string-join(child::para[position()=1],",")', 'p1', '');
  t('string-join(child::para[position()=last()] ,",")', 'p4', '');
  t('string-join(child::para[position()=last()-1] ,",")', 'p3', '');
  t('string-join(child::para[position()>1] ,",")', 'p2,p3,p4', '');
  t('string-join(following-sibling::chapter[position()=1] ,",")', '', '');
  t('string-join(chapter/following-sibling::chapter[position()=1] ,",")', 'IntroductionCDP1CDP2', '');
  t('string-join(chapter/preceding-sibling::chapter[position()=1] ,",")', 'cdp1cdp2', '');
  t('string-join(descendant::para[position()=3] ,",")', 'p3', '');
  t('string-join(descendant::para[position()=8] ,",")', 'cdp2', '');
  t('string-join(child::chapter[position()=2]/*/child::para[position()=1],",")', 'CDP1', '');
  t('string-join(child::chapter[position()=1]/*/child::para[position()=2],",")', 'cdp2', '');
  t('string-join(child::para[attribute::type="warning"],",")', 'p2,p3,p4', '');
  t('string-join(child::para[attribute::type="warning"][2],",")', 'p3', '');
  t('string-join(child::para[attribute::type="warning"][1],",")', 'p2', '');
  t('string-join(child::para[2][attribute::type="warning"],",")', 'p2', '');
  t('string-join(child::para[1][attribute::type="warning"],",")', '', '');
  t('string-join(child::chapter[child::title=''Introduction''],",")', 'IntroductionCDP1CDP2', '');
  t('string-join(child::chapter[child::title],",")', 'IntroductionCDP1CDP2', '');
  t('string-join(child::chapter[child::div],",")', 'cdp1cdp2,IntroductionCDP1CDP2', '');
  t('string-join(child::chapter[child::ti],",")', 'cdp1cdp2', '');
  t('string-join(child::chapter[child::ti or child::title],",")', 'cdp1cdp2,IntroductionCDP1CDP2', '');
  t('string-join(child::chapter[child::title or child::ti],",")', 'cdp1cdp2,IntroductionCDP1CDP2', '');
  t('string-join(child::chapter[child::title or child::ti][1],",")', 'cdp1cdp2', '');
  t('string-join(child::chapter[child::title][1],",")', 'IntroductionCDP1CDP2', '');
               //abbreviated examples
  t('string-join(para,",")', 'p1,p2,p3,p4', '');
  t('string-join(*,",")', 'p1,p2,texti,p3,XX,p4,npnp1np2,cdp1cdp2,BB,ltext,IntroductionCDP1CDP2', '');
  t('string-join(text(),",")', '','');
  t('string-join(npara/*,",")', 'np1,np2','');
  t('string-join(npara/text(),",")', 'np','');
  t('string-join(x/text(),",")', 'XX', '');
  t('string-join(para[1],",")', 'p1', '');
  t('string-join(para[last()],",")', 'p4', '');
  t('string-join(*/para,",")', 'np1,np2', '');
  t('string-join(chapter[2]/div[1]/para,",")', 'CDP1,CDP2', '');
  t('string-join(chapter[2]/div/para[1],",")', 'CDP1', '');
  t('string-join(chapter//para,",")', 'cdp1,cdp2,CDP1,CDP2', '');
  t('string-join(.//para,",")', 'p1,p2,p3,p4,np1,np2,cdp1,cdp2,CDP1,CDP2', '');
  t('string-join(x/../para,",")', 'p1,p2,p3,p4', '');
  t('string-join(para[@type="warning"],",")', 'p2,p3,p4', '');
  t('string-join(para[@type="warning"][2],",")', 'p3', '');
  t('string-join(para[4][@type="warning"],",")', 'p4', '');
  t('string-join(para[1][@type="warning"],",")', '', '');
  t('string-join(chapter[title="Introduction"],",")', 'IntroductionCDP1CDP2', '');
  t('string-join(chapter[title],",")', 'IntroductionCDP1CDP2', '');
  t('string-join(chapter[ti and title],",")', '', '');
  t('string-join(chapter[ti and div],",")', 'cdp1cdp2', '');
  t('string-join(chapter[ti and div],",")', 'cdp1cdp2', '');
  t('string-join(chapter[ti or div],",")', 'cdp1cdp2,IntroductionCDP1CDP2', '');
  t('string-join(.//para[2],",")', 'p2,np2,cdp2,CDP2', '');
  t('string-join(./descendant::para[2],",")', 'p2', '');

               {
               //examples taken from the xpath standard
               ,('','','<para>p1</para>' + '<para type="warning">p2</para>' + 'texti'+'<para type="warning">p3</para>'+'<x>XX</x>'+'<para type="warning">p4</para>'+'<npara>np<para>np1</para><para>np2</para></npara>'+
               '<chapter><ti></ti><div><para>cdp1</para><para>cdp2</para></div></chapter>'+'<b>BB</b>'+'ltext'+'<chapter><title>Introduction</title><div><para>CDP1</para><para>CDP2</para></div></chapter>')
  }


               //examples taken from http://msdn.microsoft.com/en-us/library/ms256086.aspx
  t('','','<x><y>a</y><y>b</y></x><x><y>c</y><y>d</y></x>');
  t('string-join( x/y[1], ",")', 'a,c', '');
  t('string-join( x/y[position() = 1]  , ",")', 'a,c', '');
  t('string-join(  (x/y)[1] , ",")', 'a', '');
  t('string-join(  x[1]/y[2]  , ",")', 'b', '');

               //comments
  t('0 (: ... ::: :)', '0', '');
  t('4 +(: ... ::: :)7', '11', '');
  t('4 - (: Houston, we have a problem :) 7', '-3', '');
  t('4 - (: Houston, (:we have (::)a problem:):) 7', '-3', '');
  t('(: commenting out a (: comment :) may be confusing, but often helpful :)', '', '');
  t('"abc(::)"', 'abc(::)', '');
  t('"abc(::)"(::)   (:(:(::):):)  (:*:)', 'abc(::)', '');
  t('string-join( (:..:) x[1](:x:)/(::)y[2]  , ",")', 'b', '');

               //block structures
  t('for $x in (1,2,3) return $x', '1', '');
  t('string-join(for $x in (1,2,3) return $x,",")', '1,2,3', '');
  t('string-join(for $x in (1,2,3,"4","5") return $x,",")', '1,2,3,4,5', '');
  t('string-join(for $x in (1,2,3,"4","5") return ($x + 1),",")', '2,3,4,5,6', '');
  t('string-join(for $x in (1,2,3,"4","5") return $x + 1,",")', '2,3,4,5,6', '');
  t('for $x in (1,2,3,"4","5") return $x + 1', '2', '');
  t('for $x in (1,2,3) return (for $y in (10,20,30) return $x)', '1', '');
  t('for $x in (1,2,3) return (for $y in (10,20,30) return $y)', '10', '');
  t('for $x in (1,2,3) return (for $y in (10,20,30) return $x + $y)', '11', '');
  t('string-join(for $x in (1,2,3) return (for $y in (10,20,30) return $x),",")', '1,1,1,2,2,2,3,3,3', '');
  t('string-join(for $x in (1,2,3) return (for $y in (10,20,30) return $y),",")', '10,20,30,10,20,30,10,20,30', '');
  t('string-join(for $x in (1,2,3) return (for $y in (10,20,30) return $x + $y),",")', '11,21,31,12,22,32,13,23,33', '');
  t('string-join(for $x in (1,2,3) return (for $y in (10,20,30) return $x),",")', '1,1,1,2,2,2,3,3,3', '');
  t('string-join(for $x in (1,2,3) return (for $y in (10,20,30) return $y),",")', '10,20,30,10,20,30,10,20,30', '');
  t('string-join(for $x in (1,2,3) return for $y in (10,20,30) return $x + $y,",")', '11,21,31,12,22,32,13,23,33', '');
  t('string-join(for $x in (1,2,3), $y in (10,20,30) return $x + $y,",")', '11,21,31,12,22,32,13,23,33', '');
  t('string-join(for $x in (1,2,3), $y in (10,20,30) return $x + $y + 1 * 5,",")', '16,26,36,17,27,37,18,28,38', '');
  t('for $i in (10, 20), $j in (1, 2)  return ($i + $j)', '11', '');
  t('for $i in (10, 20), $j in (1, 2)  return $i + $j', '11', '');
  t('string-join(for $i in (10, 20), $j in (1, 2)  return ($i + $j), ",")', '11,12,21,22', '');
               //For-example of the standard. Attention: The example is wrong in the standard
  t('for $a in fn:distinct-values(bib/book/author) return (bib/book/author[. = $a][1], bib/book[author = $a]/title)','Stevens','<bib>' + '  <book>' + '    <title>TCP/IP Illustrated</title>' + '    <author>Stevens</author>' + '    <publisher>Addison-Wesley</publisher>' + '  </book>' + '  <book>' + '    <title>Advanced Programming in the Unix Environment</title>' + '    <author>Stevens</author>' + '    <publisher>Addison-Wesley</publisher>' + '  </book>' + '  <book>' + '    <title>Data on the Web</title>' + '    <author>Abiteboul</author>' + '    <author>Buneman</author>' + '    <author>Suciu</author>' + '  </book>' + '</bib>' );
  t('string-join(for $a in fn:distinct-values(bib/book/author) return (bib/book/author[. = $a][1], bib/book[author = $a]/title), ",")','Stevens,Stevens,TCP/IP Illustrated,Advanced Programming in the Unix Environment,Abiteboul,Data on the Web,Buneman,Data on the Web,Suciu,Data on the Web','');
  t('for $a in fn:distinct-values(bib/book/author) return ((bib/book/author[. = $a])[1], bib/book[author = $a]/title)','Stevens','');
  t('string-join(for $a in fn:distinct-values(bib/book/author) return ((bib/book/author[. = $a])[1], bib/book[author = $a]/title), ",")','Stevens,TCP/IP Illustrated,Advanced Programming in the Unix Environment,Abiteboul,Data on the Web,Buneman,Data on the Web,Suciu,Data on the Web','');

  t('some $x in (1,2,3) satisfies $x', 'true', '');
  t('every $x in (1,2,3) satisfies $x', 'true', '');
  t('some $x in (1,2,3) satisfies ($x = 1)', 'true', '');
  t('every $x in (1,2,3) satisfies ($x = 1)', 'false', '');
  t('some $x in (1,2,3) satisfies ($x = 0)', 'false', '');
  t('every $x in (1,2,3) satisfies ($x = 0)', 'false', '');
  t('some $x in (1,2,3), $y in (1,2,3) satisfies ($x=$y)', 'true', '');
  t('every $x in (1,2,3), $y in (1,2,3) satisfies ($x=$y)', 'false', '');
  t('some $x in (1,2,3), $y in (4,5,6) satisfies ($x=$y)', 'false', '');
  t('every $x in (1,2,3), $y in (4,5,6) satisfies ($x=$y)', 'false', '');
  t('some $x in (1,1,1), $y in (1,1,1) satisfies ($x=$y)', 'true', '');
  t('every $x in (1,1,1), $y in (1,1,1) satisfies ($x=$y)', 'true', '');
  t('some $test in (2,4,6) satisfies ($test mod 2 = 0)', 'true', '');
  t('every $test in (2,4,6) satisfies ($test mod 2 = 0)', 'true', '');
  t('some $test in (2,4,7) satisfies ($test mod 2 = 0)', 'true', '');
  t('every $test in (2,4,7) satisfies ($test mod 2 = 0)', 'false', '');
  t('some $x in (1, 2, 3), $y in (2, 3, 4) satisfies $x + $y = 4', 'true', '');
  t('every $x in (1, 2, 3), $y in (2, 3, 4) satisfies $x + $y = 4', 'false', '');
  t('some $x in (1, 2, "cat") satisfies $x * 2 = 4', 'true', '');
  t('every $x in (1, 2, "cat") satisfies $x * 2 = 4', 'false', '');

  t('if ("true") then 1 else 2', '1', '');
  t('if ("false") then 1 else 2', '2', '');
  t('if (true()) then 1 else 2', '1', '');
  t('if (false()) then 1 else 2', '2', '');
  t('if (1) then 1 else 2', '1', '');
  t('if (0) then 1 else 2', '2', '');
  t('if ("a"="A") then 1 else 2', '1', '');
  t('if ("a"="b") then 1 else 2', '2', '');
  t('if ("true") then (1) else 2', '1', '');
  t('if ("false") then (1) else 2', '2', '');
  t('if (true()) then (1) else 2', '1', '');
  t('if (false()) then (1) else 2', '2', '');
  t('if (1) then (1) else 2', '1', '');
  t('if (0) then (1) else 2', '2', '');
  t('if ("a"="A") then (1) else 2', '1', '');
  t('if ("a"="b") then (1) else 2', '2', '');
  t('if ("true") then 1 else (2)', '1', '');
  t('if ("false") then 1 else (2)', '2', '');
  t('if (true()) then 1 else (2)', '1', '');
  t('if (false()) then 1 else (2)', '2', '');
  t('if (1) then 1 else (2)', '1', '');
  t('if (0) then 1 else (2)', '2', '');
  t('if ("a"="A") then 1 else (2)', '1', '');
  t('if ("a"="b") then 1 else (2)', '2', '');
  t('if ("true") then (1) else (2)', '1', '');
  t('if ("false") then (1) else (2)', '2', '');
  t('if (true()) then (1) else (2)', '1', '');
  t('if (false()) then (1) else (2)', '2', '');
  t('if (1) then (1) else (2)', '1', '');
  t('if (0) then (1) else (2)', '2', '');
  t('if ("a"="A") then (1) else (2)', '1', '');
  t('if ("a"="b") then (1) else (2)', '2', '');
  t('if (true()) then 3+4*7 else 2*2+5', '31', '');
  t('if (false()) then 3+4*7 else 2*2+5', '9', '');
  t('if (true()) then 4*7+3 else 5+2*2', '31', '');
  t('if (false()) then 4*7+3 else 5+2*2', '9', '');

  t('if (true()) then for $x in (1,2,3) return $x else for $x in (4,5,6) return $x', '1', '');
  t('string-join(if (true()) then (for $x in (1,2,3) return $x) else for $x in (4,5,6) return $x,",")', '1,2,3', '');
  t('string-join(if (false()) then (for $x in (1,2,3) return $x) else for $x in (4,5,6) return $x,",")', '4,5,6', '');
  t('string-join(if (true()) then for $x in (1,2,3) return $x else (for $x in (4,5,6) return $x),",")', '1,2,3', '');
  t('string-join(if (false()) then for $x in (1,2,3) return $x else (for $x in (4,5,6) return $x),",")', '4,5,6', '');
  t('string-join(if (true()) then (for $x in (1,2,3) return $x) else (for $x in (4,5,6) return $x),",")', '1,2,3', '');
  t('string-join(if (false()) then (for $x in (1,2,3) return $x) else (for $x in (4,5,6) return $x),",")', '4,5,6', '');
  t('string-join(if (true()) then for $x in (1,2,3) return $x else for $x in (4,5,6) return $x,",")', '1,2,3', '');
  t('string-join(if (false()) then for $x in (1,2,3) return $x else for $x in (4,5,6) return $x,",")', '4,5,6', '');
  t('string-join(for $x in (1,2,3,4,5) return if ($x mod 2 = 0) then $x else (),",")', '2,4', '');
  t('string-join(for $x in (1,2,3,4,5) return if ($x mod 2 = 1) then $x else (),",")', '1,3,5', '');
  t('string-join(for $x in (1,2,3,4,5) return if ($x mod 2 = 0) then $x else "",",")', ',2,,4,', '');
  t('deep-equal(for $x in (1,2,3,4,5) return if ($x mod 2 = 1) then $x else (),(1,3,5))', 'true', '');
  t('deep-equal(for $x in (1,2,3,4,5) return if ($x mod 2 = 1) then $x else (),(1,3,5,7))', 'false', '');
  t('for $x in 4 return $x + 1', '5', '');
  t('some $x in 4 satisfies $x + 1 = 5', 'true', '');
  t('every $x in 4 satisfies $x + 1 = 5', 'true', '');
  t('some $x in 4 satisfies $x + 1 = 4', 'false', '');
  t('every $x in 4 satisfies $x + 1 = 4', 'false', '');
  t('(some $x in 4 satisfies $x + 1 = 4) = (every $x in 4 satisfies $x + 1 = 4)', 'true', '');
  t('(some $x in 4 satisfies $x + 1 = 5) = (every $x in 4 satisfies $x + 1 = 5)', 'true', '');
  t('some $x in (1,2,3) satisfies ()', 'false', '');
  t('every $x in (1,2,3) satisfies ()', 'false', '');
  t('some $x in (1,2,3) satisfies ($x > 0)', 'true', '');
  t('every $x in (1,2,3) satisfies ($x > 0)', 'true', '');
  t('some $x in 1 to 3 satisfies ($x > 0)', 'true', '');
  t('every $x in 1 to 3 satisfies ($x > 0)', 'true', '');
  t('string-join(for $x in 1 to 10 return 2*$x,",")', '2,4,6,8,10,12,14,16,18,20', '');
  t('for $x in (1,2,3), $y in (1,2) return concat("x",$x,"y",$y)', 'x1y1', '');
  t('string-join(for $x in (1,2,3), $y in (1,2) return concat("x",$x,"y",$y),",")', 'x1y1,x1y2,x2y1,x2y2,x3y1,x3y2', '');
  t('for $i in (1, 2), $j in (1, 2)  return $i + $j', '2', '');
  t('for $i in (1,2  ), $j in (1,2) return $i + $j', '2', '');
  t('for $i in (1,2,3), $j in (1,2) return $i+$j', '2', '');
  t('for $x in (1,2,3), $y in (1,2) return $y+$x', '2', '');
  t('for $x in (1,2,3), $y in (1,2) return ($y*$x)', '1', '');
  t('for $x in (1,2,3), $y in (1,2) return $y*$x', '1', '');
  t('for $x in 1 to 3, $y in (1,2) return $y*$x', '1', '');
  t('string-join(for $x in 1 to 3, $y in (1,2) return $y*$x,",")', '1,2,2,4,3,6', '');
  t('string-join(for $x in 1 to 3, $y in (1,2) return $y*$x;,",")', '1,2,2,4,3,6', '');
  t('some $x in 1 to 3, $y in (1,2) satisfies $x = $y', 'true', '');
  t('every $x in 1 to 3, $y in (1,2) satisfies $x = $y', 'false', '');
  t('some $x in 1 to 3, $y in (1,2) satisfies $x > $y', 'true', '');
  t('some $x in 1 to 3, $y in (-1,-2) satisfies $x > $y', 'true', '');
  t('every $x in 1 to 3, $y in (1,2) satisfies $x > $y', 'false', '');
  t('every $x in 1 to 3, $y in (-1,-2) satisfies $x > $y', 'true', '');
  t('every $x in 1 to 3, $y in (for $k in (1,2) return -1*$k) satisfies $x > $y', 'true', '');
  t('for $x in 1 to 3, $y in (for $k in (1,2) return -1*$k) return concat($x,">",$y)', '1>-1', '');
               //Amazing overloaded meanings
  t('', '', '<for><return>RR</return><in>a<return>ar</return><return>ar2</return></in><in>b</in><in><return>cr</return>c<return>cr2</return></in><return>RX</return><if>F<then>THN</then><else>LS</else></if></for>');
  t('for $for in for/in return $for/return', 'ar', '');
  t('string-join(for $for in for/in return $for/return,",")', 'ar,ar2,cr,cr2', '');
  t('string-join(for $for in for/in return $for,",")', 'aarar2,b,crccr2', '');
  t('string-join(for $for in for/in return for/return,",")', 'RR,RX,RR,RX,RR,RX', '');
  t('string-join(for $for in for/in return for,",")', 'RRaarar2bcrccr2RXFTHNLS,RRaarar2bcrccr2RXFTHNLS,RRaarar2bcrccr2RXFTHNLS', '');
  t('string-join(for $for in for/in return return,",")', '', '');
  t('string-join(for $for in for/in, $in in $for/return return $in,",")', 'ar,ar2,cr,cr2', '');
  t('string-join(for $for in for/* return $for/then,",")', 'THN', '');
  t('string-join(for $for in for/* return for/then,",")', '', '');
  t('string-join(for $for in for/* return for/if/then,",")', 'THN,THN,THN,THN,THN,THN', '');
  t('string-join(for $for in for/* return for/*/then,",")', 'THN,THN,THN,THN,THN,THN', '');
  t('string-join(for $for in for/if return $for/then,",")', 'THN', '');
  t('string-join(for,",")', 'RRaarar2bcrccr2RXFTHNLS', '');
  t('string-join(for/in,",")', 'aarar2,b,crccr2', '');
  t('string-join(for | for/in,",")', 'RRaarar2bcrccr2RXFTHNLS,aarar2,b,crccr2', '');
  t('some $x in for satisfies $x/return', 'true', '');
  t('some $x in for satisfies $x/in/return', 'true', '');
  t('some $x in for/in satisfies $x/return', 'true', '');
  t('some $x in for/in satisfies $x/return[2]', 'true', '');
  t('some $x in for satisfies for', 'true', '');
  t('some $x in for satisfies return', 'false', '');
  t('some $x in for satisfies for/return', 'true', '');
  t('some $x in for satisfies for/in/return', 'true', '');
  t('some $x in for satisfies satisfies', 'false', '');
  t('every $x in for satisfies $x/return', 'true', '');
  t('every $x in for satisfies $x/in/return', 'true', '');
  t('every $x in for/in satisfies $x/return', 'false', '');
  t('every $x in for/in satisfies $x/return[2]', 'false', '');
  t('every $x in for satisfies for', 'true', '');
  t('every $x in for satisfies return', 'false', '');
  t('every $x in for satisfies for/return', 'true', '');
  t('every $x in for satisfies for/in/return', 'true', '');
  t('every $x in for satisfies satisfies', 'false', '');
  t('some $satisfies in satisfies satisfies satisfies', 'true', '<satisfies></satisfies>');
  t('every $satisfies in satisfies satisfies satisfies', 'true', '');
  t('some $satisfies in satisfies satisfies satisfiesx', 'false', '');
  t('every $satisfies in satisfies satisfies satisfiesx', 'false', '');
  t('some $satisfies in satisfiesx satisfies satisfies', 'false', '');
  t('every $satisfies in satisfiesx satisfies satisfies', 'true', '');
  t('some $satisfies in satisfiesx satisfies satisfiesx', 'false', '');
  t('every $satisfies in satisfiesx satisfies satisfiesx', 'true', '');
  t('some $satisfies in satisfies satisfies satisfies/satisfies', 'false', '');
  t('every $satisfies in satisfies satisfies satisfies/satisfies', 'false', '');
  t('some $satisfies in satisfies satisfies satisfies/satisfies', 'true', '<satisfies><satisfies><satisfies></satisfies></satisfies></satisfies>');
  t('every $satisfies in satisfies satisfies satisfies/satisfies', 'true', '');
  t('some $satisfies in satisfies satisfies satisfies/satisfies/satisfies', 'true', '');
  t('every $satisfies in satisfies satisfies satisfies/satisfies/satisfies', 'true', '');
  t('some $satisfies in satisfies satisfies satisfies/satisfies/satisfies/satisfies', 'false', '');
  t('every $satisfies in satisfies satisfies satisfies/satisfies/satisfies/satisfies', 'false', '');
  t('some $satisfies in satisfies/satisfies satisfies satisfies/satisfies/satisfies', 'true', '');
  t('every $satisfies in satisfies/satisfies satisfies satisfies/satisfies/satisfies', 'true', '');
  t('some $satisfies in satisfies/satisfies satisfies satisfies/satisfies/satisfies/satisfies', 'false', '');
  t('every $satisfies in satisfies/satisfies satisfies satisfies/satisfies/satisfies/satisfies', 'false', '');
  t('some $satisfies in satisfies/satisfies satisfies $satisfies/satisfies', 'true', '');
  t('every $satisfies in satisfies/satisfies satisfies $satisfies/satisfies', 'true', '');
  t('some $satisfies in satisfies/satisfies satisfies $satisfies/satisfies/satisfies', 'false', '');
  t('every $satisfies in satisfies/satisfies satisfies $satisfies/satisfies/satisfies', 'false', '');
  t('some $satisfies in satisfies/satisfies/satisfies satisfies $satisfies', 'true', '');
  t('every $satisfies in satisfies/satisfies/satisfies satisfies $satisfies', 'true', '');
  t('some $satisfies in satisfies/satisfies/satisfies satisfies $satisfies/satisfies', 'false', '');
  t('every $satisfies in satisfies/satisfies/satisfies satisfies $satisfies/satisfies', 'false', '');
  t('some $satisfies in satisfies/satisfies/satisfies/satisfies satisfies $satisfies', 'false', '');
  t('every $satisfies in satisfies/satisfies/satisfies/satisfies satisfies $satisfies', 'true', '');
  t('if (true) then some $satisfies in satisfies satisfies satisfies else every $satisfies in satisfies satisfies satisfies', 'true', '');
  t('if (false) then some $satisfies in satisfies satisfies satisfies else every $satisfies in satisfies satisfies satisfies', 'true', '');
  t('for $in in in return in', 'A', '<in>A</in><in>B</in>');
  t('string-join(for $in in in return in,",")', 'A,B,A,B', '<in>A</in><in>B</in>');
  t('for $in in return return return', 't', '<return>t</return>');
  t('for $in in if return if', 't', '<if>t</if>');
  t('for $in in some return some', 't', '<some>t</some>');
  t('for $in in div return idiv', 'y', '<div>x</div><idiv>y</idiv>');
  t('every $a in () satisfies $a = ">a<" ', 'true', '');
  t('some $a in for $x in div/x return concat(">",$x,"<") satisfies $a = ">a<" ', 'true', '<div><x>a</x><x>b</x><x>c</x></div>');
  t('every $a in for $x in div/x return concat(">",$x,"<") satisfies $a = ">a<" ', 'false', '');
  t('some $a in for $x in div/x return concat(">",$x,"<") satisfies $a = ">x<" ', 'false', '');
  t('every $a in for $x in div/x return concat(">",$x,"<") satisfies $a = ">x<" ', 'false', '');
  t('some $a in for $x in div/xy return concat(">",$x,"<") satisfies $a = ">x<" ', 'false', '');
  t('string-join(for $x in div/xy return concat(">",$x,"<"),";") ', '', '');
  t('every $a in for $x in div/xy return concat(">",$x,"<") satisfies $a = ">x<" ', 'true', '');  //empty sequence, so every is always satisfied
  t('some $a in for $x in div/x return concat(">",$x,"<") satisfies $a = (">x<",">y") ', 'false', '');
  t('every $a in for $x in div/x return concat(">",$x,"<") satisfies $a = (">x<",">y<") ', 'false', '');
  t('some $a in for $x in div/x return concat(">",$x,"<") satisfies $a = (">a<",">b<",">c<",">d<") ', 'true', '');
  t('every $a in for $x in div/x return concat(">",$x,"<") satisfies $a = (">a<",">b<",">c<",">d<") ', 'true', '');

               //Variable defining
  t('x := 123', '123', '');
  t('$x', '123', '');
  t('$X', '', '');
  t('X := 456', '456', '');
  t('$x', '123', '');
  t('$X', '456', '');
  t('jh:=concat($X,"COE")', '456COE', '');
  t('$jh', '456COE', '');
  t('maus := "haus"', 'haus', '');
  t('$maus', 'haus', '');
  t('$maus := "haus2"', 'haus2', '');
  t('$maus', 'haus2', '');
  t('$maus:= "haus3"', 'haus3', '');
  t('$maus', 'haus3', '');
  t('$maus;:= "haus4"', 'haus4', '');
  t('$maus', 'haus4', '');
  t('a := 1, b:= 2', '1', '');
  t('$a', '1', '');
  t('$b', '2', '');
  t('a := 10, A:= 20', '10', '');
  t('$a', '10', '');
  t('$b', '2', '');
  t('$A', '20', '');
  t('concat($a,";",$b,";",$A)', '10;2;20', '');
  t('a := 1, b:= ($a * 3), c := $b + 7', '1', '');
  t('concat($a,";",$b,";",$c)', '1;3;10', '');
  t('a := (1,2,3,42), b:= 4+5, c:=2*3 + 1, d:=a/text()', '1', '<a>hallo</a>');
  t('string-join($a,";")', '1;2;3;42', '');
  t('concat($b,";",$c,";",$d)', '9;7;hallo', '');
  t('x := for $y in $a return $y+10 ', '11', '');
  t('string-join($x,",")', '11,12,13,52', '');
  t('string-join(m := (1,2,3),",")', '1,2,3', '');
  t('string-join($m,",")', '1,2,3', '');
  t('string-join((m := (1,2,3), b := (4,5,6), c:=(7,8,9)),",")', '1,2,3,4,5,6,7,8,9', '');
  t('string-join($m,",")', '1,2,3', '');
  t('string-join($b,",")', '4,5,6', '');
  t('string-join($c,",")', '7,8,9', '');
  t('string-join((m := (1,2,3), b := ($m, 10), c:=(100,$b, 1000)),",")', '1,2,3,1,2,3,10,100,1,2,3,10,1000', '');
  t('if (1 = 1) then a := 10 else a := 20', '10', '');
  t('$a', '10', '');
  t('if (() = 1) then a := 10 else a := 20', '20', '');
  t('$a', '20', '');
  t('concat(eval("a:=30, b := 12"), $a, $b)', '303012', '');


               //collations
  t('starts-with("tattoo", "tat", "http://www.benibela.de/2012/pxp/case-insensitive-clever")', 'true', '');
  t('starts-with("tattoo", "att", "http://www.benibela.de/2012/pxp/case-insensitive-clever")', 'false', '');
  t('starts-with("tattoo", "TAT", "http://www.benibela.de/2012/pxp/case-insensitive-clever")', 'true', '');
  t('starts-with("tattoo", "tat", "case-insensitive-clever")', 'true', '');
  t('starts-with("tattoo", "att", "case-insensitive-clever")', 'false', '');
  t('starts-with("tattoo", "TAT", "case-insensitive-clever")', 'true', '');
  t('starts-with("tattoo", "tat", "http://www.benibela.de/2012/pxp/case-sensitive-clever")', 'true', '');
  t('starts-with("tattoo", "att", "http://www.benibela.de/2012/pxp/case-sensitive-clever")', 'false', '');
  t('starts-with("tattoo", "TAT", "http://www.benibela.de/2012/pxp/case-sensitive-clever")', 'false', '');
  t('starts-with("tattoo", "tat", "case-sensitive-clever")', 'true', '');
  t('starts-with("tattoo", "att", "case-sensitive-clever")', 'false', '');
  t('starts-with("tattoo", "TAT", "case-sensitive-clever")', 'false', '');
  t('starts-with("tattoo", "tat", "http://www.w3.org/2005/xpath-functions/collation/codepoint/")', 'true', '');
  t('starts-with("tattoo", "att", "http://www.w3.org/2005/xpath-functions/collation/codepoint/")', 'false', '');
  t('starts-with("tattoo", "TAT", "http://www.w3.org/2005/xpath-functions/collation/codepoint/")', 'false', '');
  t('starts-with("tattoo", "TAT", "http://www.w3.org/2005/xpath-functions/collation/codepoint")', 'false', '');
  t('starts-with("tattoo", "tat", "fpc-localized-case-insensitive")', 'true', '');
  t('starts-with("tattoo", "att", "fpc-localized-case-insensitive")', 'false', '');
  t('starts-with("tattoo", "TAT", "fpc-localized-case-insensitive")', 'true', '');
  t('starts-with("tattoo", "tat", "fpc-localized-case-sensitive")', 'true', '');
  t('starts-with("tattoo", "att", "fpc-localized-case-sensitive")', 'false', '');
  t('starts-with("tattoo", "TAT", "fpc-localized-case-sensitive")', 'false', '');
  t('starts-with("tattoo", "tat", "http://www.benibela.de/2012/pxp/fpc-localized-case-insensitive")', 'true', '');
  t('starts-with("tattoo", "att", "http://www.benibela.de/2012/pxp/fpc-localized-case-insensitive")', 'false', '');
  t('starts-with("tattoo", "TAT", "http://www.benibela.de/2012/pxp/fpc-localized-case-insensitive")', 'true', '');
  t('starts-with("tattoo", "tat", "http://www.benibela.de/2012/pxp/fpc-localized-case-sensitive")', 'true', '');
  t('starts-with("tattoo", "att", "http://www.benibela.de/2012/pxp/fpc-localized-case-sensitive")', 'false', '');
  t('starts-with("tattoo", "TAT", "http://www.benibela.de/2012/pxp/fpc-localized-case-sensitive")', 'false', '');
               //,('starts-with("äöüaou", "ÄÖÜA", "fpc-localized-case-insensitive")', 'true', '')
               //,('starts-with("äöüaou", "ÄÖÜA", "fpc-localized-case-sensitive")', 'false', '')
  t('ends-with("tattoo", "too", "http://www.benibela.de/2012/pxp/case-insensitive-clever")', 'true', '');
  t('ends-with("tattoo", "atto", "http://www.benibela.de/2012/pxp/case-insensitive-clever")', 'false', '');
  t('ends-with("tattoo", "TTOO", "http://www.benibela.de/2012/pxp/case-insensitive-clever")', 'true', '');
  t('ends-with("tattoo", "too", "http://www.benibela.de/2012/pxp/case-sensitive-clever")', 'true', '');
  t('ends-with("tattoo", "atto", "http://www.benibela.de/2012/pxp/case-sensitive-clever")', 'false', '');
  t('ends-with("tattoo", "TTOO", "http://www.benibela.de/2012/pxp/case-sensitive-clever")', 'false', '');
  t('string-join(distinct-values(("a", "A", "aA", "AA")),",")', 'a,aA', '');
  t('string-join(distinct-values(("a", "A", "aA", "AA"), "http://www.benibela.de/2012/pxp/case-insensitive-clever"),",")', 'a,aA', '');
  t('string-join(distinct-values(("a", "A", "aA", "AA"), "http://www.benibela.de/2012/pxp/case-sensitive-clever"),",")', 'a,A,aA,AA', '');
  t('deep-equal(("A","B"), ("a","b"), "http://www.benibela.de/2012/pxp/case-insensitive-clever")', 'true', '');
  t('deep-equal(("A","B"), ("a","bc"), "http://www.benibela.de/2012/pxp/case-insensitive-clever")', 'false', '');
  t('deep-equal(("A","B"), ("A","B"), "http://www.benibela.de/2012/pxp/case-sensitive-clever")', 'true', '');
  t('deep-equal(("A","B"), ("a","b"), "http://www.benibela.de/2012/pxp/case-sensitive-clever")', 'false', '');
  t('deep-equal(("A","B"), ("a","bc"), "http://www.benibela.de/2012/pxp/case-sensitive-clever")', 'false', '');
  t('max(("10haus", "100HAUS", "2haus", "099haus", "100haus"))', '100haus', '');
  t('max(("10haus", "100haus", "2haus", "099haus", "100HAUS"))', '100HAUS', '');
  t('max(("10haus", "100haus", "2haus", "099haus", "100HAUS"), "http://www.benibela.de/2012/pxp/case-insensitive-clever")', '100HAUS', '');
  t('max(("10haus", "100HAUS", "2haus", "099haus", "100haus"), "http://www.benibela.de/2012/pxp/case-insensitive-clever")', '100haus', '');
  t('max(("10haus", "100haus", "2haus", "099haus", "100HAUS"), "http://www.benibela.de/2012/pxp/case-sensitive-clever")', '100haus', '');
  t('max(("10haus", "100HAUS", "2haus", "099haus", "100haus"), "http://www.benibela.de/2012/pxp/case-sensitive-clever")', '100haus', '');
  t('max(("10haus", "100haus", "2haus", "099haus", "100HAUS"), "fpc-localized-case-insensitive")', '2haus', '');
  t('max(("10haus", "100HAUS", "2haus", "099haus", "100haus"), "fpc-localized-case-insensitive")', '2haus', '');
  t('max(("10haus", "100haus", "2haus", "099haus", "100HAUS"), "fpc-localized-case-sensitive")', '2haus', '');
  t('max(("10haus", "100HAUS", "2haus", "099haus", "100haus"), "fpc-localized-case-sensitive")', '2haus', '');
  t('min(("10haus", "100haus", "2haus", "099haus", "2HAUS"))', '2haus', '');
  t('min(("10haus", "100haus", "2HAUS", "099haus", "2haus"))', '2HAUS', '');
  t('min(("10haus", "100haus", "2haus", "099haus", "2HAUS"), "http://www.benibela.de/2012/pxp/case-insensitive-clever")', '2haus', '');
  t('min(("10haus", "100HAUS", "2HAUS", "099haus", "2haus"), "http://www.benibela.de/2012/pxp/case-insensitive-clever")', '2HAUS', '');
  t('min(("10haus", "100haus", "2haus", "099haus", "2HAUS"), "http://www.benibela.de/2012/pxp/case-sensitive-clever")', '2HAUS', '');
  t('min(("10haus", "100HAUS", "2HAUS", "099haus", "2haus"), "http://www.benibela.de/2012/pxp/case-sensitive-clever")', '2HAUS', '');
  t('min(("10haus", "100haus", "2haus", "099haus", "2HAUS"), "fpc-localized-case-sensitive")', '099haus', '');
  t('min(("10haus", "100haus", "2HAUS", "099haus", "2haus"), "fpc-localized-case-sensitive")', '099haus', '');
  t('min(("10haus", "100haus", "2haus", "099haus", "2HAUS"), "fpc-localized-case-insensitive")', '099haus', '');
  t('min(("10haus", "100haus", "2HAUS", "099haus", "2haus"), "fpc-localized-case-insensitive")', '099haus', '');
  t('default-collation()', 'http://www.benibela.de/2012/pxp/case-insensitive-clever', '');

               //IDs
  t('string-join(id("a"),",")', 'singleA', '<html>void<y id="c">singleC</y><raven id=" ">nevermore</raven><table><x id="a">singleA</x><z id="b">doubleB</z></table>void<end id="b">doubleB2</end></html>');
  t('string-join(id("b"),",")', 'doubleB,doubleB2', '');
  t('string-join(id("z"),",")', '', '');
  t('string-join(id("a b c"),",")', 'singleC,singleA,doubleB,doubleB2', '');
  t('string-join(id(("a b", "c")),",")', 'singleC,singleA,doubleB,doubleB2', '');
  t('string-join(id(("a       b", "c")),",")', 'singleC,singleA,doubleB,doubleB2', '');
  t('string-join(id(" "),",")', '', '');
  t('static-base-uri()', 'pseudo://test', '');

               //http://www.dpawson.co.uk/xsl/rev2/exampler2.html
               //http://www.w3.org/TR/xslt20/#function-function-available?? that's xsl not xpath

               {$DEFINE PXP_DERIVED_TYPES_UNITTESTS}
               {$I ../xquery_derived_types.inc}

  t('123 instance of anyAtomicType', 'true', '');
  t('(5,4,2) instance of anyAtomicType', 'false', '');
  t('(5,4,2) instance of anyAtomicType+', 'true', '');
  t('123.6 instance of anySimpleType', 'true', '');
  t('xs:Name("B4") instance of anyType', 'true', '');
  //             ,('(5,4,2) instance of anySimpleType', 'true', '') todo: check ??
  //             ,('(5,4,2) instance of anyType', 'true', '') todo: check??

                //durations
  t('yearMonthDuration("P1Y1M") * 0.5', 'P7M', '');
  t('dayTimeDuration("P4D") ', 'P4D', '');
  t('duration("P1Y2M3D") ', 'P1Y2M3D', '');
  t('duration("P1Y2M3DT5H6M70S") ', 'P1Y2M3DT5H7M10S', '');
  t('duration("P0Y0M0DT5H6M70.123S") ', 'PT5H7M10.123S', '');
  t('duration("P0M") ', 'PT0S', '');
  t('yearMonthDuration("P0Y0M") ', 'P0M', '');
  t('dayTimeDuration("PT0H0S") ', 'PT0S', '');
  t('dayTimeDuration("PT1H") ', 'PT1H', '');
  t('dayTimeDuration("-PT1H") ', '-PT1H', '');
  t('yearMonthDuration("-P3Y") ', '-P3Y', '');
  t('yearMonthDuration("P4Y0M") div 2 ', 'P2Y', '');
  t('dayTimeDuration("P3D") div 4', 'PT18H', '');
  t('xs:dayTimeDuration("PT2H2M") div xs:dayTimeDuration("PT1H1M")', '2', '');
  t('xs:yearMonthDuration("P1Y") div xs:yearMonthDuration("P3M")', '4', '');
  t('xs:yearMonthDuration("P7M") + xs:yearMonthDuration("P6M")', 'P1Y1M', '');
  t('xs:dayTimeDuration("P7D") + xs:dayTimeDuration("PT3H")', 'P7DT3H', '');
  t('xs:date("2012-12-20") + xs:dayTimeDuration("P4D")', '2012-12-24', '');
  t('xs:date("2012-12-20") + xs:dayTimeDuration("P4DT20H")', '2012-12-24', '');
  t('(xs:date("2012-12-20") + xs:dayTimeDuration("P4DT20H")) + xs:dayTimeDuration("P4DT20H")', '2012-12-28', '');
  t('xs:date("2012-12-20") - xs:dayTimeDuration("P4DT20H")', '2012-12-15', '');
  t('xs:date("2012-12-24") - xs:date("2012-12-20")', 'P4D', '');
  t('timezone-from-datetime(xs:date("2012-12-30+05:30"))', 'PT5H30M', '');
  t('timezone-from-date(xs:date("2012-12-30Z"))', 'PT0S', '');
  t('timezone-from-time(xs:time("02:18:20-1203"))', '-PT12H3M', '');
     {
  t('', '', '');
  t('', '', '');
               ,('', '', '')}
               //from the xpath standard
  t('xs:dayTimeDuration("PT2H10M") * 2.1', 'PT4H33M', '');
  t('xs:yearMonthDuration("P2Y11M") * 2.3', 'P6Y9M', '');
  t('xs:dayTimeDuration("P1DT2H30M10.5S") div 1.5', 'PT17H40M7S', '');
  t('xs:yearMonthDuration("P2Y11M") div 1.5', 'P1Y11M', '');
  t('xs:dayTimeDuration("P2DT53M11S") div xs:dayTimeDuration("PT1S")', '175991', '');
  t('fn:round-half-to-even( xs:dayTimeDuration("P2DT53M11S") div xs:dayTimeDuration("P1DT10H"), 4)', '1.4378', '');
  t('xs:yearMonthDuration("P3Y4M") div xs:yearMonthDuration("P1M")', '40', '');
  t('xs:yearMonthDuration("P3Y4M") div xs:yearMonthDuration("-P1Y4M")', '-2.5', '');
  t('xs:dayTimeDuration("PT2H10M") * 2.1', 'PT4H33M', '');
  t('xs:yearMonthDuration("P2Y11M") * 2.3', 'P6Y9M', '');
  t('xs:dayTimeDuration("P2DT12H5M") + xs:dayTimeDuration("P5DT12H")', 'P8DT5M', '');
  t('xs:date("2004-10-30Z") + xs:dayTimeDuration("P2DT2H30M0S")', '2004-11-01Z', '');
  t('xs:dateTime("2000-10-30T11:12:00") + xs:dayTimeDuration("P3DT1H15M")', '2000-11-02T12:27:00', '');
  t('xs:time("11:12:00") + xs:dayTimeDuration("P3DT1H15M")', '12:27:00', '');
  t('xs:time("23:12:00+03:00") + xs:dayTimeDuration("P1DT3H15M")', '02:27:00+03:00', '');
  t('xs:yearMonthDuration("P2Y11M") + xs:yearMonthDuration("P3Y3M")', 'P6Y2M', '');
  t('xs:date("2000-10-30") + xs:yearMonthDuration("P1Y2M")', '2001-12-30', '');
  t('xs:dateTime("2000-10-30T11:12:00") + xs:yearMonthDuration("P1Y2M")', '2001-12-30T11:12:00', '');
  t('xs:date("2000-10-30") - xs:dayTimeDuration("P3DT1H15M")', '2000-10-26', '');
  t('xs:dateTime("2000-10-30T11:12:00") - xs:dayTimeDuration("P3DT1H15M")', '2000-10-27T09:57:00', '');
  t('xs:time("11:12:00") - xs:dayTimeDuration("P3DT1H15M")', '09:57:00', '');
  t('xs:time("08:20:00-05:00") - xs:dayTimeDuration("P23DT10H10M")', '22:10:00-05:00', '');
  t('xs:date("2000-10-30") - xs:yearMonthDuration("P1Y2M")', '1999-08-30', '');
  t('op:subtract-yearMonthDuration-from-date(xs:date("2000-02-29Z"), xs:yearMonthDuration("P1Y"))', '1999-02-28Z', '');
  t('op:subtract-yearMonthDuration-from-date(xs:date("2000-10-31-05:00"), xs:yearMonthDuration("P1Y1M"))', '1999-09-30-05:00', '');
  t('op:subtract-yearMonthDuration-from-dateTime(xs:dateTime("2000-10-30T11:12:00"), xs:yearMonthDuration("P1Y2M"))', '1999-08-30T11:12:00', '');
  t('op:subtract-dayTimeDurations(xs:dayTimeDuration("P2DT12H"), xs:dayTimeDuration("P1DT10H30M"))', 'P1DT1H30M', '');
  t('op:subtract-yearMonthDurations(xs:yearMonthDuration("P2Y11M"), xs:yearMonthDuration("P3Y3M"))', '-P4M', '');
  t('op:subtract-dates(xs:date("2000-10-30"), xs:date("1999-11-28"))', 'P337D', '');
  t('op:subtract-dateTimes(xs:dateTime("2000-10-30T06:12:00-05:00"), xs:dateTime("1999-11-28T09:00:00Z"))', 'P337DT2H12M', '');
  t('op:subtract-times(xs:time("11:12:00Z"), xs:time("04:00:00-05:00"))', 'PT2H12M', '');
  t('op:subtract-times(xs:time("11:00:00-05:00"), xs:time("21:30:00+05:30"))', 'PT0S', '');
  t('op:subtract-times(xs:time("17:00:00-06:00"), xs:time("08:00:00+09:00"))', 'P1D', '');
  t('op:subtract-times(xs:time("24:00:00"), xs:time("23:59:59"))', '-PT23H59M59S', '');
  t('op:subtract-times(xs:time("24:00:00"), xs:time("23:59:59"))', '-PT23H59M59S', '');
  t('fn:adjust-dateTime-to-timezone(xs:dateTime("2002-03-07T10:00:00"))', '2002-03-07T10:00:00-05:00', '');
  t('fn:adjust-dateTime-to-timezone(xs:dateTime(''2002-03-07T10:00:00-07:00''))', '2002-03-07T12:00:00-05:00', '');
  t('fn:adjust-dateTime-to-timezone(xs:dateTime("2002-03-07T10:00:00"), xs:dayTimeDuration("-PT10H"))', '2002-03-07T10:00:00-10:00', '');
  t('fn:adjust-dateTime-to-timezone(xs:dateTime("2002-03-07T10:00:00-07:00"), xs:dayTimeDuration("-PT10H"))', '2002-03-07T07:00:00-10:00', '');
  t('adjust-dateTime-to-timezone(xs:dateTime("2002-03-07T10:00:00-07:00"), xs:dayTimeDuration("PT10H"))', '2002-03-08T03:00:00+10:00', '');
  t('fn:adjust-dateTime-to-timezone(xs:dateTime(''2002-03-07T00:00:00+01:00''), xs:dayTimeDuration("-PT8H"))', '2002-03-06T15:00:00-08:00', '');
  t('fn:adjust-dateTime-to-timezone(xs:dateTime(''2002-03-07T10:00:00''), ())','2002-03-07T10:00:00','');
  t('fn:adjust-dateTime-to-timezone(xs:dateTime(''2002-03-07T10:00:00-07:00''), ())','2002-03-07T10:00:00','');
  t('hours-from-dateTime(fn:adjust-dateTime-to-timezone(xs:dateTime("2002-03-07T10:00:00-07:00"), xs:dayTimeDuration("-PT10H")))', '7', '');
  t('fn:local-name-from-QName(fn:QName("http://www.example.com/example", "pn:person"))', 'person', '');
  t('fn:prefix-from-QName(fn:QName("http://www.example.com/example", "pn:person"))', 'pn', '');
  t('fn:namespace-uri-from-QName(fn:QName("http://www.example.com/example", "pn:person"))', 'http://www.example.com/example', '');
  t('fn:local-name-from-QName(fn:QName("http://www.example.com/example", "person"))', 'person', '');
  t('fn:prefix-from-QName(fn:QName("http://www.example.com/example", "person"))', '', '');
  t('fn:namespace-uri-from-QName(fn:QName("http://www.example.com/example", "person"))', 'http://www.example.com/example', '');
  t('fn:local-name-from-QName(fn:QName("person"))', 'person', '');
  t('fn:namespace-uri-from-QName(fn:QName("person"))', '', '');
  t('//x', '2', '!<abc id="a" xml:lang="en-US">1<x>2</x>3</abc>');
  t('fn:root(//x)', '123', '');
  t('fn:root()', '123', '');
  t('outer-xml(root(//x))', '<abc id="a" xml:lang="en-US">1<x>2</x>3</abc>', '');
  t('node-name(root(//x))', '', '');
  t('fn:root()/abc/@id', 'a', '');
  t('fn:root(//x)/abc/@id', 'a', '');
  t('lang("en")', 'true', '');
  t('lang("en-")', 'false', '');
  t('lang("en", //x)', 'true', '');
  t('lang("En", //x)', 'true', '');
  t('nilled(/abc/x)', 'true', '!<abc id="a" xml:lang="en-US">1<x xml:nil="true"></x><y xml:nil="true">as</y><z xml:nil="false"></z></abc>');
  t('nilled(/abc/y)', 'false', '');
  t('nilled(/abc/z)', 'false', '');
  t('data(/abc/y)', 'as', '');
  t('string-join(data(/abc/y),",")', 'as', '');
  t('type-of(data(/abc/y))', 'untypedAtomic', '');
  t('namespace-uri-from-QName(resolve-QName("t:abc", r/sub))', 'test', '<r xmlns="default" xmlns:t="test"><sub></sub><override xmlns:t="test2"><sub/></override></r>');
  t('namespace-uri-from-QName(resolve-QName("t:abc", r/override/sub))', 'test2', '');
  t('namespace-uri-from-QName(resolve-QName("abc", r/override/sub))', 'default', '');
  t('namespace-uri-from-QName(resolve-QName((), r/override/sub))', '', '');
  t('namespace-uri-for-prefix("t", r/override/sub)', 'test2', '');
  t('namespace-uri-for-prefix((), r/override/sub)', 'default', '');
  t('string-join(in-scope-prefixes(r/override/sub),",")', 't,', '');
  t('trace(152, "a")', '152', '');
  t('resolve-uri("/def", "http://www.example.com/a/b/c")', 'http://www.example.com/def', '');
  t('resolve-uri("#frag", "http://www.example.com/a/b/c")', 'http://www.example.com/a/b/c#frag', '');
  t('resolve-uri("?param#frag", "http://www.example.com/a/b/c")', 'http://www.example.com/a/b/c?param#frag', '');
  t('resolve-uri("d?param#frag", "http://www.example.com/a/b/c")', 'http://www.example.com/a/b/d?param#frag', '');
  t('resolve-uri("./.././../", "http://www.example.com/a/b/c")', 'http://www.example.com/', '');
  t('resolve-uri("./.././../", "http://www.example.com/a/b/c/")', 'http://www.example.com/a/', '');
  t('resolve-uri("./.././../ghi", "http://www.example.com/a/b/c")', 'http://www.example.com/ghi', '');
  t('resolve-uri("./.././../ghi", "http://www.example.com/a/b/c/")', 'http://www.example.com/a/ghi', '');
  t('resolve-uri("ghi", "file:///home/example/.config/foobar")', 'file:///home/example/.config/ghi', '');
  t('resolve-uri("ghi", "file:///home/example/.config/foobar/")', 'file:///home/example/.config/foobar/ghi', '');
  t('resolve-uri("../ghi", "file:///home/example/.config/foobar")', 'file:///home/example/ghi', '');
  t('resolve-uri("../ghi", "file:///home/example/.config/foobar/")', 'file:///home/example/.config/ghi', '');
  t('resolve-uri("/tmp/abc", "file:///home/example/.config/foobar")', 'file:///tmp/abc', '');
  t('fn:encode-for-uri("http://www.example.com/00/Weather/CA/Los%20Angeles#ocean")', 'http%3A%2F%2Fwww.example.com%2F00%2FWeather%2FCA%2FLos%2520Angeles%23ocean', '');
  t('concat("http://www.example.com/", encode-for-uri("~bébé"))', 'http://www.example.com/~b%C3%A9b%C3%A9', '');
  t('concat("http://www.example.com/", encode-for-uri("100% organic"))', 'http://www.example.com/100%25%20organic', '');
  t('fn:iri-to-uri ("http://www.example.com/00/Weather/CA/Los%20Angeles#ocean")', 'http://www.example.com/00/Weather/CA/Los%20Angeles#ocean', '');
  t('fn:iri-to-uri ("http://www.example.com/~bébé")', 'http://www.example.com/~b%C3%A9b%C3%A9', '');
  t('fn:escape-html-uri ("http://www.example.com/00/Weather/CA/Los Angeles#ocean")', 'http://www.example.com/00/Weather/CA/Los Angeles#ocean', '');
  t('fn:escape-html-uri ("javascript:if (navigator.browserLanguage == ''fr'') window.open(''http://www.example.com/~bébé'');")', 'javascript:if (navigator.browserLanguage == ''fr'') window.open(''http://www.example.com/~b%C3%A9b%C3%A9'');', '');
  t('base-uri(doc/paragraph/link)', 'http://example.org/today/xy/', '<doc xml:base="http://example.org/today/"><paragraph xml:base="xy"><link xlink:type="simple" xlink:href="new.xml"></link>!</paragraph></doc>');
  t('name(./tmp/*)', 'pr:abc', '<tmp xmlns:pr="http://www.example.com"><pr:abc></pr:abc></tmp>');
  t('name(./tmp/element())', 'pr:abc', '');
  t('local-name(./tmp/element())', 'abc', '');
  t('namespace-uri(./tmp/element())', 'http://www.example.com', '');
  t('type-of(temp := xs:byte(12))', 'byte', '');
  t('$temp', '12', '');
  t('type-of($temp)', 'byte', '');


               //Objects extension
  t('obj := xs:object()', '', '');
  t('obj.foo := "bar"', 'bar', '');
  t('$obj.foo', 'bar', '');
  t('obj.foo := 123', '123', '');
  t('obj.foo := $obj.foo * 2', '246', '');
  t('obj.o := $obj', '', '');
  t('$obj.o.foo', '246', '');
  t('$obj.bar := 17', '17', '');
               //,('$obj.o.bar', '', '')
  t('obj.o.foo := "new"', 'new', '');
  t('$obj.o.foo', 'new', '');
  t('$obj.foo', '246', '');
  t('$obj.bar', '17', '');
  t('obj.o.p := $obj', '', '');
  t('$obj.o.p.foo', '246', '');
  t('$obj.o.p.o.foo', 'new', '');
  t('obj.o.p.o := xs:object()', '', '');
  t('$obj.o.p.o.foo', '', '');
  t('obj.o.p.o.foo := 99', '99', '');
  t('$obj.o.p.o.foo', '99', '');
  t('test := object()', '', '');
  t('test.t1 := 1', '1', '');
  t('test.t2 := 2', '2', '');
  t('test.t3 := 3', '3', '');
  t('test.t4 := 4', '4', '');
  t('$test.t1', '1', '');
  t('$test.t2', '2', '');
  t('$test.t3', '3', '');
  t('$test.t4', '4', '');
  t('test.foo:bar := 123', '123', '');
  t('$test.foo:bar', '123', '');
  t('$test.foo:bar := 456', '456', ''); //good idea to allow both??
  t('$test.foo:bar', '456', '');
  t('obj := xs:object(("a", "b", "c", 123))', '', '');
  t('$obj.a', 'b', '');
  t('$obj.b', '', '');
  t('$obj.c', '123', '');
  t('"a$obj.c;b"', 'a123b', '');
  t('''a$obj.c;b''', 'a$obj.c;b', '');
  t('type-of($obj.c)', 'integer', '');
  t('(object(("x", "y")), object(("u", "v")))', '', '');
  t('(object(("x", "y")), object(("u", "v")))[1].x', 'y', '');
  t('(object(("x", "y")), object(("u", "v")))[1].u', '', '');
  t('(object(("x", "y")), object(("u", "v")))[2].u', 'v', '');

  t('string-join(for $i in object(("a", "x", "b", "Y", "c", "Z")).a return $i, "|")', 'x', '');
  t('string-join(for $i in object(("a", "x", "b", "Y", "c", "Z")) return $i.a, "|")', 'x', '');
  t('string-join(for $i in object(("a", "x", "b", "Y", "c", "Z")) return ($i.b,$i.c), "|")', 'Y|Z', '');
  t('string-join(for $i in (object(("abc", "123")), object(("abc", "456")), object(("abc", "789"))) return $i.abc, "|")', '123|456|789', '');
  t('string-join(for $i in (object(("abc", "123")), object(("abc", "456")), object(("abc", "789"))) return "$i.abc;", "|")', '123|456|789', '');
  t('string-join((i := object(("a", 1)), for $i in object(("a", "2")) return $i.a), "|")', '|2', '');
  t('string-join((i := object(("a", 1)), for $i in object(("b", "2")) return $i.a), "|")', '', '');
  t('string-join((i := object(("a", 1)), for $i in (object(("b", "2")),object(("a", "3"))) return $i.a), "|")', '|3', '');



               //Tests based on failed XQTS tests
  t('count(a/attribute::*)', '0', '<a></a>');
  t('count(a/attribute::node())', '0', '<a></a>'); //my
  t('count(a/attribute::node())', '2', '<a a="abc" x="foo"></a>'); //my
  t('count(a/attribute())', '0', '<a></a>'); //my
  t('count(a/attribute())', '2', '<a a="abc" x="foo"></a>'); //my
  t('count(a/attribute::attribute())', '0', '<a></a>'); //my
  t('count(a/attribute::attribute())', '2', '<a a="abc" x="foo"></a>'); //my
  t('count(a/attribute(*))', '0', '<a></a>'); //my
  t('count(a/attribute(*))', '2', '<a a="abc" x="foo"></a>'); //my
  t('count(a/attribute::attribute(*))', '0', '<a></a>'); //my
  t('count(a/attribute::attribute(*))', '2', '<a a="abc" x="foo"></a>'); //my
  t('string-join(for $i in //descendant-or-self::*  return node-name($i), ";")', 'html', '!<html></html>');
  t('string-join(for $i in .//descendant-or-self::*  return node-name($i), ";")', 'html', '!<html></html>');
  t('string-join(for $i in .//descendant-or-self::*  return node-name($i), ";")', 'html', '!<html></html>');
  t('string-join(for $i in /node() return node-name($i), ";")', 'abc;html', '!<?abc?><html/>');
  t('string-join(for $i in /node() return node-name($i), ";")', 'abc;html', '!<?abc ?><html/>');
  t('string-join(for $i in /node() return node-name($i), ";")', 'abc;html', '!<?abc foo="bar"?><html/>');
  t('string-join(for $i in /* return node-name($i), ";")', 'html', '!<?abc?><html/>');
  t('string-join(for $i in /node() return node-name($i), ";")', 'abc;def;html', '!<?abc?><?def ?><html/>');
  t('string-join(for $i in /processing-instruction() return node-name($i), ";")', 'abc;def', '!<?abc?><?def ?><html/>');
  t('string-join(for $i in /processing-instruction(def) return node-name($i), ";")', 'def', '!<?abc?><?def ?><html/>');
  t('string-join(for $i in /processing-instruction("abc") return node-name($i), ";")', 'abc', '!<?abc?><?def ?><html/>');
  t('string-join(//self::*,";")', 'abcxfoobar;x', '!<html>abc<test>x</test>foobar</html>');
  t('string-join(time/x/a[3]/preceding::*,";")', 'q;1;2', '<time><p>q</p>t<x>u<a>1</a><a>2</a><a>3</a></x></time>');
  t('string-join(time/x/a[3]/preceding::a,";")', '1;2', '<time><p>q</p>t<x>u<a>1</a><a>2</a><a>3</a></x></time>');
               //instance of tests (still failed xqts)
  t('4 instance of item()', 'true', '');
  t('(4,5) instance of item()', 'false', '');
  t('(4,5) instance of item()+', 'true', '');
  t('() instance of item()+', 'false', '');
  t('() instance of empty-sequence()', 'true', '');
  t('(3) instance of empty-sequence()', 'false', '');
  t('/a instance of node()', 'true', '!<a>hallo<!--comment--></a>');
  t('/a instance of element()', 'true', '');
  t('/a instance of comment()', 'false', '');
  t('/a instance of processing-instruction()', 'false', '');
  t('/a instance of text()', 'false', '');
  t('/a/text() instance of node()', 'true', '');
  t('/a/text() instance of element()', 'false', '');
  t('/a/text() instance of comment()', 'false', '');
  t('/a/text() instance of processing-instruction()', 'false', '');
  t('/a/text() instance of text()', 'true', '');
  t('/a/comment() instance of node()', 'true', '');
  t('/a/comment() instance of element()', 'false', '');
  t('/a/comment() instance of comment()', 'true', '');
  t('/a/comment() instance of processing-instruction()', 'false', '');
  t('/a/comment() instance of text()', 'false', '');
  t('/a/node() instance of node()', 'true', '!<a><?option?></a>');
  t('/a/node() instance of text()', 'false', '');
  t('/a/node() instance of element()', 'false', '');
  t('/a/node() instance of comment()', 'false', '');
  t('/a/node() instance of processing-instruction()', 'true', '');
  t('xs:float(1) castable as xs:string', 'true', '');
  t('if (xs:float(1.5) castable as xs:string) then 1 else 2', '1', '');
  t('if (xs:float(1.5) castable as xs:integer) then 1 else 2', '1', '');
  t('if (xs:float("NaN") castable as xs:integer) then 1 else 2', '2', '');
  t('/td[if (true()) then true() else false()]', '', '');
  t('true() instance of anyAtomicType', 'true', '');
  t('QName("abc")', 'abc', '');
               //,('QName("abc", "def")', 'abc', '')
  t('','','');
  t('xs:gMonth("--12") castable as decimal', 'false', '');
  t('xs:dateTime("2030-12-05") castable as decimal', 'false', '');
  t('(0.0 div 0.0)', 'NaN', '');
  t('(0.0 div 0.0) castable as xs:integer', 'false', '');
  t('xs:float(0.0 div 0.0)', 'NaN', '');
  t('xs:float(0.0 div 0.0) castable as xs:integer', 'false', '');
  t('xs:base64Binary("0FB7")', '0FB7', '');
  t('xs:hexBinary("07fb")', '07FB', '');
  t('xs:hexBinary(base64Binary("YWJj"))', '616263', '');
  t('xs:hexBinary("616263") eq xs:base64Binary("YWJj")', 'true', ''); //don't know if true or false
  t('xs:hexBinary("616263") castable as xs:boolean', 'false', '');
  t('xs:hexBinary("616263") castable as xs:decimal', 'false', '');
  t('true() castable as xs:decimal', 'true', '');
  t('xs:dateTime("2012-12-12") castable as xs:decimal', 'false', '');
  t('xs:dateTime("2012-12-12") castable as xs:gMonth', 'true', '');
  t('xs:gMonth("--12") castable as xs:dateTime', 'false', '');
  t('xs:gMonthDay("--12-05") castable as xs:gMonth', 'false', '');
  t('xs:gMonth("--12") castable as xs:gMonthDay', 'false', '');
  t('xs:gMonth("--12") castable as xs:boolean', 'false', '');
  t('xs:string("1999-05-31Z") castable as xs:date', 'true', '');
  t('xs:string("ABA") castable as xs:hexBinary', 'false', '');
  t('xs:double(123.456) castable as xs:decimal', 'true', '');
  t('xs:double("INF") castable as xs:decimal', 'false', '');
  t('xs:double("INF") castable as xs:float', 'true', '');
  t('"INF" castable as xs:float', 'true', '');
  t('gDay("---30") castable as xs:hexBinary', 'false', '');
  t('/a castable as xs:integer', 'true', '!<a>100</a>');
  t('/a castable as xs:integer', 'false', '!<a>abc</a>');
  t('xs:date("1999-05-17") cast as xs:dateTime', '1999-05-17T00:00:00', '');
  t('xs:date("-0753-12-05") cast as xs:dateTime', '-0753-12-05T00:00:00', '');
  t('xs:time("12:12:12.5") - xs:time("12:12:12")', 'PT0.5S', '');
  t('fn:month-from-dateTime(fn:dateTime(xs:date("1999-12-31+10:00"), xs:time("23:00:00+10:00")))', '12', '');
  t('xs:datetime("1999-12-30T20:30:40.5")', '1999-12-30T20:30:40.5', '');
  t('xs:date("1999-07-19") - xs:date("1969-11-30")', 'P10823D', '');
  t('(xs:date("1999-07-19") - xs:date("1969-11-30")) eq xs:dayTimeDuration("P10823D")', 'true', '');
  t('fn:datetime(date("1999-12-30"), time("20:30:40.23-05"))', '1999-12-30T20:30:40.23-05:00', '');
  t('fn:datetime(date("1999-12-30+04"), time("20:30:40.23"))', '1999-12-30T20:30:40.23+04:00', '');
  t('op:subtract-dates(xs:date("2000-10-30"), xs:date("1999-11-28"))', 'P337D', '');
  t('(op:subtract-dates(xs:date("2000-10-30"), xs:date("1999-11-28"))) + dayTimeDuration("P1D")', 'P338D', '');
  t('dayTimeDuration("P1D") + (op:subtract-dates(xs:date("2000-10-30"), xs:date("1999-11-28")))', 'P338D', '');
  t('xs:date("0001-01-01") - xs:date("-0001-12-31")', 'P1D', '');
  t('xs:date("0001-01-01") + xs:dayTimeDuration("-P1D")', '-0001-12-31', '');
  t('xs:date("0001-01-01") + xs:yearMonthDuration("-P1M")', '-0001-12-01', '');
  t('xs:date("0001-01-01") + xs:yearMonthDuration("-P3M")', '-0001-10-01', '');
  t('xs:date("0001-01-01") + xs:yearMonthDuration("-P12M")', '-0001-01-01', '');
  t('xs:date("0001-01-01") + xs:yearMonthDuration("-P13M")', '-0002-12-01', '');
  t('xs:date("0001-01-01") + xs:yearMonthDuration("-P16M")', '-0002-09-01', '');
  t('years-from-duration(xs:yearMonthDuration("-P16M"))', '-1', '');
  t('fn:seconds-from-duration(xs:dayTimeDuration("P3DT10H12.5S"))', '12.5', '');
  t('fn:seconds-from-duration(xs:dayTimeDuration("-PT256S"))', '-16', '');
  t('fn:minutes-from-duration(xs:dayTimeDuration("-P5DT12H30M"))', '-30', '');
  t('fn:hours-from-duration(xs:dayTimeDuration("PT123H"))', '3', '');
  t('fn:days-from-duration(xs:yearMonthDuration("P3Y5M"))', '0', '');
  t('fn:days-from-duration(xs:dayTimeDuration("P3DT55H"))', '5', '');
  t('xs:yearMonthDuration("P6M")+xs:yearMonthDuration("P6M")', 'P1Y', '');
  t('xs:yearMonthDuration("P18M")-xs:yearMonthDuration("P6M")', 'P1Y', '');
  t('xs:yearMonthDuration("P6M")-xs:yearMonthDuration("P18M")', '-P1Y', '');
  t('xs:yearMonthDuration("P20Y123M")', 'P30Y3M', '');
  t('xs:yearMonthDuration("P3Y36M") div xs:yearMonthDuration("P60Y")  eq 0.1', 'true', '');
  t('xs:date("2004-12-30") castable as gMonth', 'true', '');
  t('xs:time("20:03:04") castable as gMonth', 'false', '');
  t('xs:hexBinary("20") castable as gMonth', 'false', '');
  t('xs:time("20:03:04") castable as duration', 'false', '');
  t('QName("example.com/", "p:ncname") ne QName("example.com/", "p:ncnameNope")', 'true', '');
  t('fn:QName("http://www.example.com/example1", "person") eq fn:QName("http://www.example.com/example2", "person")', 'false', '');
  t('2.e3', '2000', '');
  t('.2', '0.2', '');
  t('""""', '"', '');
  t('''''''''', '''', '');
  t('duration("P1YT4H") - duration("P12MT240M")', 'PT0S', '');
  t('sum((dayTimeDuration("PT1S"), dayTimeDuration("PT2S")))', 'PT3S', '');
  t('sum((yearMonthDuration("P1M"), yearMonthDuration("P11M")))', 'P1Y', '');
  t('type-of(sum((dayTimeDuration("PT1S"), dayTimeDuration("PT2S"))))', 'dayTimeDuration', '');
  t('type-of(sum((yearMonthDuration("P1M"), yearMonthDuration("P11M"))))', 'yearMonthDuration', '');
  t('sum(a/b)', '6', '<a><b>1</b><b>2</b><b>3</b></a>');
  t('type-of(sum(a/b))', 'double', '');
  t('max((dayTimeDuration("PT1S"), dayTimeDuration("PT2S")))', 'PT2S', '');
  t('max(a/b)', '3', '');
  t('type-of(max(a/b))', 'double', '');
  t('min((dayTimeDuration("PT1S"), dayTimeDuration("PT2S")))', 'PT1S', '');
  t('min(a/b)', '1', '');
  t('min((xs:decimal("NaN"), 1))', 'NaN', '');
  t('type-of(min(a/b))', 'double', '');
  t('avg((dayTimeDuration("PT1S"), dayTimeDuration("PT2S")))', 'PT1.5S', '');
  t('avg(a/b)', '2', '');
  t('type-of(avg(a/b))', 'double', '');
  t('xs:float("INF") + xs:float("-INF")', 'NaN', '');
  t('5 + xs:float("-INF")', '-INF', '');
  t('5 - xs:float("-INF")', 'INF', '');
  t('xs:float("-INF") * 0', 'NaN', '');
  t('xs:float("INF") - xs:float("INF")', 'NaN', '');
  t('xs:float("INF") div xs:float("INF")', 'NaN', '');
  t('xs:float("NaN") mod 5', 'NaN', '');
  t('xs:float("5") mod xs:float("-INF")', '5', '');
  t('xs:gYearMonth("2005-02Z")', '2005-02Z', '');
  t('xs:gYearMonth("2005-02Z") = xs:gYearMonth("2005-02Z")', 'true', '');
  t('seconds-from-dateTime(xs:dateTime("18:23:45.123"))', '45.123', '');
  t('xs:dateTime("-0001-12-31T24:00:00")', '0001-01-01T00:00:00', '');
  t('xs:float(1.01)', '1.01', '');
  t('fn:compare("abc", "abc")', '0', '');
  t('fn:compare("abc", ())', '', '');
  t('/a/b/c/lang("de")', 'true', '!<a><b><c xml:lang="de"></c></b></a>');
  t('node-name(//c)', 'c', '!<a><b><c xml:lang="de"></c></b></a>');
  t('for $var in (1,2,3,4,5) return $var', '1', '');
  t('fn:resolve-uri("abc", "http://www.example.com")' ,'http://www.example.com/abc', '');
  t('fn:resolve-uri("", "http://www.example.com")' ,'http://www.example.com', '');
  t('fn:resolve-uri("", "http://www.example.com/")' ,'http://www.example.com/', '');
  t('fn:resolve-uri("", "http://www.example.com/")' ,'http://www.example.com/', '');
  t('fn:resolve-uri(".", "http://www.example.com/")' ,'http://www.example.com/', '');
  t('fn:resolve-uri(".", "http://www.example.com/")' ,'http://www.example.com/', '');
  t('fn:resolve-uri("././c", "http://www.example.com")' ,'http://www.example.com/c', '');
  t('fn:resolve-uri("././c", "http://www.example.com/")' ,'http://www.example.com/c', '');
  t('fn:tokenize("abc", "def")', 'abc', '');
  t('fn:type-of(abs(xs:byte(1)))', 'integer', ''); //standard, abs: If the type of $arg is a type derived from one of the numeric types, the result is an instance of the base numeric type.
  t('abs(negativeInteger(-3))', '3', '');
  t('type-of(number(-3))', 'double', '');
  t('not(double("NaN"))', 'true', '');
  t('subsequence((1,2), 4)', '', '');
  t('string-join((), "...") eq ""', 'true', '');
  t('tokenize("", "abc") eq ""', 'false', '');
  t('/', '12', '!<a>12</a>');
  t('(/) * 3', '36', '');
  t('4 + /', '16', '');
  t('string-join(/a//b, ",")', '1,2,3,4,5,6', '!<a><b>1</b><c><b>2</b><b>3</b></c><d><b>4</b><b>5</b></d><b>6</b></a>');
  t('string-join(/a//b/parent::d, ",")', '45', '');
  t('string-join(/a//b[1], ",")', '1,2,4', '');
  t('string-join(/a//b[2], ",")', '3,5,6', '');
  t('string-join(/a//(b[2]), ",")', '3,5,6', '');
  t('string-join(/a//(if (b[2]) then b[2] else ()), ",")', '3,5,6', '');
  t('string-join(/a//(if (b[2]) then string(b[2]) else ()), ",")', '6,3,5', '');
  t('string-join(/a//b[3], ",")', '', '');
  t('string-join((/a//b)[1], ",")', '1', '');
  t('string-join((/a//b)[2], ",")', '2', '');
  t('string-join((/a//b)[3], ",")', '3', '');
  t('string-join(/a//b[2]/parent::*, ",")', '123456,23,45', '');
  t('string-join((/a//b)[2]/parent::*, ",")', '23', '');
  t('round(xs:double("INF"))', 'INF', '');
  t('round(xs:double("-INF"))', '-INF', '');
  t('round(xs:double("NaN"))', 'NaN', '');
  t('round-half-to-even(xs:double("INF"))', 'INF', '');
  t('round-half-to-even(xs:double("-INF"), 5)', '-INF', '');
  t('xs:float("  5  ")', '5', '');
  t('xs:boolean("  true  ")', 'true', '');
  t('xs:boolean("  false  ")', 'false', ''); //<- not xpath but here
  t('xs:hexBinary("  56  ")', '56', '');
  t('xs:gMonth("  --03  ") eq xs:gMonth("--03")', 'true', '');
  t('xs:anyURI("  http://www.example.com  ") eq xs:anyURI("http://www.example.com")', 'true', '');
  t('xs:string(xs:hexBinary(" abcd ")) eq "ABCD"', 'true', '');
  t('codepoints-to-string(()) eq ""', 'true', '');
  t('xs:date(xs:dateTime("2002-11-23T22:12:23.867-13:37"))', '2002-11-23-13:37', '');
  t('xs:date(xs:dateTime("2002-11-23T22:12:23.867-13:37")) eq xs:date("2002-10-23-13:37")', 'false', '');
  t('xs:date(xs:dateTime("2002-11-23T22:12:23.867-13:37")) eq xs:date("2002-11-23-13:37")', 'true', '');
  t('xs:string(xs:dateTime("2002-02-15T21:01:23.110"))', '2002-02-15T21:01:23.11', '');
  t('xs:string(xs:time("21:01:23.001"))', '21:01:23.001', '');
  t('xs:date(xs:dateTime("2002-11-23T22:12:23.867-13:37")) eq xs:date("2002-11-23-13:37")', 'true', '');
  t('xs:time("12:12:12") eq xs:date("2012-12-13")', 'false', '');
  t('xs:dateTime("2002-11-23T22:12:23.867-13:37") eq xs:time("22:12:23.867-13:37")', 'true', '');
  t('xs:dateTime("2002-11-23T22:12:23.867-13:37") eq xs:time("22:12:23-13:37")', 'false', '');
  t('xs:dateTime("2002-11-23T22:12:23.867-13:37") eq xs:time("23:12:23.867-12:37")', 'true', '');
  //             ,('xs:dateTime("2002-11-23T22:12:23.867-13:37") eq xs:time("24:12:23.867-11:37")', 'true', '') should this work?
  t('xs:dateTime("2002-11-23T22:12:23.867-13:37") eq xs:time("11:49:23.867Z")', 'false', ''); //day overflow?
  t('(xs:gYear("2005-12:00") eq xs:gYear("2005+12:00"))', 'false', '');
  t('(xs:gDay("---12") eq xs:gDay("---12Z"))', 'false', '');
  t('xs:time("08:00:00+09:00") eq xs:time("17:00:00-06:00")', 'false', ''); //from xpath standard example
  t('op:time-equal(xs:time("21:30:00+10:30"), xs:time("06:00:00-05:00"))', 'true', ''); //from xpath standard example
  t('op:time-equal(xs:time("24:00:00+01:00"), xs:time("00:00:00+01:00"))', 'true', ''); //from xpath standard example
  t('xs:duration("-P1YT2.3S")', '-P1YT2.3S', '');
  t('xs:dayTimeDuration(xs:yearMonthDuration("-P543Y456M"))', 'PT0S', '');
  t('deep-equal(xs:float("NaN"),xs:double("NaN"))', 'true', '');
  t('count(distinct-values((xs:float("NaN"),xs:double("NaN"))))', '1', '');
  //             ,('count(distinct-values((xs:float("INF"),xs:double("INF"))))', '1', '')

    //           ,('xs:date(1999-05-17) cast as xs:dateTime', '1999-05-31T00:00:00', '')
               //,('/a/processing-instruction(option) instance of node()', 'false', '') todo


               //---------------------------------CSS Selectors-----------------------------------
               //some examples from the standard (their css, my own xml)
  t('', '', '<x><a hreflang="en" class="warning">a1</a><a hreflang="de" id="myid">a2</a><a hreflang="fr-en-de">a3</a></x>');
  t('string-join(css("a"), ",")', 'a1,a2,a3', '');
  t('string-join(css("#myid"), ",")', 'a2', '');
  t('string-join(css("*#myid"), ",")', 'a2', '');
  t('string-join(css(".warning"), ",")', 'a1', '');
  t('string-join(css("*.warning"), ",")', 'a1', '');
  t('string-join(css("*[hreflang=en]"), ",")', 'a1', '');
  t('string-join(css("[hreflang=en]"), ",")', 'a1', '');
  t('string-join(css("*[hreflang|=en]"), ",")', 'a1,a3', '');
  t('string-join(css("[hreflang|=en]"), ",")', 'a1,a3', '');
  t('', '', '<x><h1>A</h1><h1 title="T">B</h1><h1 title>C</h1><span class="example">S1</span><span hello="Cleveland">S2</span><span hello="Cleveland" class="EXAMPLE">S3</span><span goodbye="Columbus">S4</span><span hello="Cleveland" goodbye="Columbus">S5</span><a rel="copyright copyleft copyeditor">A1</a><a href="http://www.w3.org/">A2</a><a rel="copyright" href="http://www.w3.org/index.html">A3</a><a rel="xyzcopyrightfoo">A4</a><DIALOGUE character="romeo">D1</DIALOGUE><DIALOGUE character="juliet">D2</DIALOGUE></x>');
  t('string-join(css("h1[title]"), ",")', 'B,C', '');
  t('string-join(css("span[class=''example'']"), ",")', 'S1,S3', '');
  t('string-join(css("span[hello=''Cleveland''][goodbye=Columbus]"), ",")', 'S5', '');
  t('string-join(css(''a[rel~="copyright"]''), ",")', 'A1,A3', '');
  t('string-join(css(''a[href="http://www.w3.org/"]''), ",")', 'A2', '');
  t('string-join(css(''DIALOGUE[character=romeo]''), ",")', 'D1', '');
  t('string-join(css(''DIALOGUE[character=juliet]''), ",")', 'D2', '');
  t('string-join(css(''object[type^="image/"]''), ",")', 'O1,O2', '<x><object type="image/123">O1</object><object type="IMAGE/">O2</object><object type="image">O3</object></x>');
  t('string-join(css(''a[href$=".html"]''), ",")', 'A3', '<a href="http://xyz.com">A1</a><a href="http://xyz.com/test.gif">A2</a><a href="http://xyz.com/test.html">A3</a>');
  t('string-join(css(''p[title*="hello"]''), ",")', 'P2,P3', '<p title="foobar">P1</p><p title="xyzhelloyzxy">P2</p><p title="hello">P3</p>');
  t('string-join(css(''p[*|title*="hello"]''), ",")', 'P2,P3', '');
  t('string-join(css(''p[xyz|title*="hello"]''), ",")', 'P2,P3', ''); //namespace are ignored. TODO: namespaces
  t('string-join(css(''p[|title*="hello"]''), ",")', 'P2,P3', '');
  t('string-join(css(''*.pastoral''), ",")', 'S1,Very green,P1,P2', '<span class="pastoral">S1</span><H1>Not green</H1><H1 class="pastoral">Very green</H1><p class="pastoral blue aqua marine">P1</p><p class="pastoral blue">P2</p>');
  t('string-join(css(''.pastoral''), ",")', 'S1,Very green,P1,P2', '');
  t('string-join(css(''H1.pastoral''), ",")', 'Very green', '');
  t('string-join(css(''p.pastoral.marine''), ",")', 'P1', '');

  t('string-join(css(''h1#chapter1''), ",")', 'ha', '<body><h1 id="chapter1">ha</h1><span id="z98y">S</span></body>');
  t('string-join(css(''#chapter1''), ",")', 'ha', '');
  t('string-join(css(''*#z98y''), ",")', 'S', '');
  t('string-join(css(''h1#chapter1''), ",")', '', '<body><h2 id="chapter1">ha</h2><span id="z98y">S</span></body>');
  t('string-join(css(''#chapter1''), ",")', 'ha', '');

  t('string-join(css(''tr:nth-child(7)''), ",")', '7', '<table><tr><td>1</td></tr> <tr><td>2</td></tr> <tr><td>3</td></tr> <tr><td>4</td></tr> <tr><td>5</td></tr> <tr><td>6</td></tr> <tr><td>7</td></tr> <tr><td>8</td></tr> <tr><td>9</td></tr> <tr><td>10</td></tr> <tr><td>11</td></tr> <tr><td>12</td></tr> <tr><td>13</td></tr> <tr><td>14</td></tr> <tr><td>15</td></tr> <tr><td>16</td></tr> <tr><td>17</td></tr> <tr><td>18</td></tr> <tr><td>19</td></tr> <tr><td>20</td></tr> </table>');
  t('string-join(css(''tr:nth-child(2n+1)''), ",")', '1,3,5,7,9,11,13,15,17,19', '');
  t('string-join(css(''tr:nth-child(odd)''), ",")', '1,3,5,7,9,11,13,15,17,19', '');
  t('string-join(css(''tr:nth-child(2n+0)''), ",")', '2,4,6,8,10,12,14,16,18,20', '');
  t('string-join(css(''tr:nth-child(even)''), ",")', '2,4,6,8,10,12,14,16,18,20', '');
  t('string-join(css('':nth-child(10n-1)''), ",")', '9,19', '');
  t('string-join(css('':nth-child(10n+9)''), ",")', '9,19', '');
  t('string-join(css('':nth-child(0n+5)''), ",")', '5', '');
  t('string-join(css('':nth-child(5)''), ",")', '5', '');
  t('string-join(css('':nth-child(1n+0)''), ",")', '1234567891011121314151617181920,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,19,20,20', '');
  t('string-join(css('':nth-child(n+0)''), ",")', '1234567891011121314151617181920,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,19,20,20', '');
  t('string-join(css('':nth-child(n)''), ",")', '1234567891011121314151617181920,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,19,20,20', '');
  t('string-join(css(''tr:nth-child(2n)''), ",")', '2,4,6,8,10,12,14,16,18,20', '');
  t('string-join(css(''tr:nth-child( 3n + 1 )''), ",")', '1,4,7,10,13,16,19', '');
  t('string-join(css(''tr:nth-child( +3n - 2 )''), ",")', '1,4,7,10,13,16,19', '');
  t('string-join(css(''tr:nth-child( -n+ 6)''), ",")', '1,2,3,4,5,6', '');
  t('string-join(css(''tr:nth-child( +6 )''), ",")', '6', '');

  t('string-join(css(''tr:nth-of-type(7)''), ",")', '7', '');
  t('string-join(css(''tr:nth-of-type(2n+1)''), ",")', '1,3,5,7,9,11,13,15,17,19', '');
  t('string-join(css(''tr:nth-of-type(odd)''), ",")', '1,3,5,7,9,11,13,15,17,19', '');
  t('string-join(css(''tr:nth-of-type(2n+0)''), ",")', '2,4,6,8,10,12,14,16,18,20', '');
  t('string-join(css(''tr:nth-of-type(even)''), ",")', '2,4,6,8,10,12,14,16,18,20', '');
  t('string-join(css('':nth-of-type(10n-1)''), ",")', '9,19', '');
  t('string-join(css('':nth-of-type(10n+9)''), ",")', '9,19', '');
  t('string-join(css('':nth-of-type(0n+5)''), ",")', '5', '');
  t('string-join(css('':nth-of-type(5)''), ",")', '5', '');
  t('string-join(css('':nth-of-type(1n+0)''), ",")', '1234567891011121314151617181920,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,19,20,20', '');
  t('string-join(css('':nth-of-type(n+0)''), ",")', '1234567891011121314151617181920,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,19,20,20', '');
  t('string-join(css('':nth-of-type(n)''), ",")', '1234567891011121314151617181920,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,19,20,20', '');
  t('string-join(css(''tr:nth-of-type(2n)''), ",")', '2,4,6,8,10,12,14,16,18,20', '');
  t('string-join(css(''tr:nth-of-type( 3n + 1 )''), ",")', '1,4,7,10,13,16,19', '');
  t('string-join(css(''tr:nth-of-type( +3n - 2 )''), ",")', '1,4,7,10,13,16,19', '');
  t('string-join(css(''tr:nth-of-type( -n+ 6)''), ",")', '1,2,3,4,5,6', '');
  t('string-join(css(''tr:nth-of-type( +6 )''), ",")', '6', '');

  t('string-join(css(''tr:nth-last-child(7)''), ",")', '14', '');
  t('string-join(css(''tr:nth-last-child(-n+2)''), ",")', '19,20', '');
  t('string-join(css(''tr:nth-last-child(odd)''), ",")', '2,4,6,8,10,12,14,16,18,20', '');
  t('string-join(css(''tr:nth-last-child(even)''), ",")', '1,3,5,7,9,11,13,15,17,19', '');

  t('string-join(css(''tr:nth-last-of-type(7)''), ",")', '14', '');
  t('string-join(css(''tr:nth-last-of-type(-n+2)''), ",")', '19,20', '');
  t('string-join(css(''tr:nth-last-of-type(odd)''), ",")', '2,4,6,8,10,12,14,16,18,20', '');
  t('string-join(css(''tr:nth-last-of-type(even)''), ",")', '1,3,5,7,9,11,13,15,17,19', '');

  t('string-join(css(''tr:nth-child(odd):nth-child(3n)''), ",")', '3,9,15', '');
  t('string-join(css(''tr:nth-child(odd):nth-child(7)''), ",")', '7', '');
  t('string-join(css(''tr:nth-child(odd):nth-child(odd)''), ",")', '1,3,5,7,9,11,13,15,17,19', '');
  t('string-join(css(''tr:nth-child(odd):nth-last-child(odd)''), ",")', '', '');
  t('string-join(css(''tr:nth-child(odd):nth-last-child(even)''), ",")', '1,3,5,7,9,11,13,15,17,19', '');
  t('string-join(css(''tr:nth-child(n+2):nth-last-child(n+2)''), ",")', '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19', '');
  t('string-join(css(''table  tr:nth-child(n+2):nth-last-child(n+2)''), ",")', '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19', '');
  t('string-join(css(''table > tr:nth-child(n+2):nth-last-child(n+2)''), ",")', '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19', '');


  t('string-join(css(''h1:nth-of-type( 2 )''), ",")', 'H2', '<div><h1>H1</h1><h1>H2</h1><span>S1</span><span>S2</span><span>S3</span><span>S4</span></div>');
  t('string-join(css(''span:nth-of-type( 2 )''), ",")', 'S2', '');
  t('string-join(css('':nth-of-type( 2 )''), ",")', 'H2,S2', '');
  t('string-join(css(''h1:nth-child( 2 )''), ",")', 'H2', '');
  t('string-join(css(''span:nth-child( 2 )''), ",")', '', '');
  t('string-join(css('':nth-child( 2 )''), ",")', 'H2', '');
  t('string-join(css(''h1:nth-last-of-type( 2 )''), ",")', 'H1', '');
  t('string-join(css(''span:nth-last-of-type( 2 )''), ",")', 'S3', '');
  t('string-join(css('':nth-last-of-type( 2 )''), ",")', 'H1,S3', '');
  t('string-join(css(''h1:nth-last-child( 2 )''), ",")', '', '');
  t('string-join(css(''span:nth-last-child( 2 )''), ",")', 'S3', '');
  t('string-join(css('':nth-last-child( 2 )''), ",")', 'S3', '');

  t('string-join(css(''h1:first-child''), ",")', 'H1', '');
  t('string-join(css(''h1:last-child''), ",")', '', '');
  t('string-join(css(''span:first-child''), ",")', '', '');
  t('string-join(css(''span:last-child''), ",")', 'S4', '');
  t('string-join(css(''*''), ",")', 'H1H2S1S2S3S4,H1,H2,S1,S2,S3,S4', '');
  t('string-join(css('':first-child''), ",")', 'H1H2S1S2S3S4,H1', '');
  t('string-join(css('':last-child''), ",")', 'H1H2S1S2S3S4,S4', '');

  t('string-join(css(''h1:first-of-type''), ",")', 'H1', '');
  t('string-join(css(''h1:last-of-type''), ",")', 'H2', '');
  t('string-join(css(''span:first-of-type''), ",")', 'S1', '');
  t('string-join(css(''span:last-of-type''), ",")', 'S4', '');
  t('string-join(css('':first-of-type''), ",")', 'H1H2S1S2S3S4,H1,S1', '');
  t('string-join(css('':last-of-type''), ",")', 'H1H2S1S2S3S4,H2,S4', '');

  t('string-join(css(''div > p:first-child''), ",")', 'The first P inside the note.', '<p> The last P before the note.</p> <div class="note">  <p> The first P inside the note.</p> </div>');
  t('string-join(css(''p:only-child''), ",")', 'The first P inside the note.', '');
  t('string-join(css('':first-child''), ",")', 'The last P before the note.,The first P inside the note.', '');
  t('string-join(css('':first-child:last-child''), ",")', 'The first P inside the note.', '');
  t('string-join(css(''p:only-of-type''), ",")', 'The last P before the note.,The first P inside the note.', '');
  t('string-join(css('':only-of-type''), ",")', 'The last P before the note.,The first P inside the note.,The first P inside the note.', '');
  t('string-join(css(''div > p:first-child''), ",")', '', '<p> The last P before the note.</p><div class="note">    <h2> Note </h2>   <p> The first P inside the note.</p></div>');
  t('string-join(css(''dl dt:first-of-type''), ",")', 'gigogne,fusée', '<dl> <dt>gigogne</dt> <dd>  <dl>   <dt>fusée</dt>   <dd>multistage rocket</dd>   <dt>table</dt>   <dd>nest of tables</dd>  </dl> </dd></dl>');

  t('count(css(''p''))', '2', '<x><p></p><foo>bar</foo><foo><bar>bla</bar></foo><foo>this is not <bar>:empty</bar></foo><p>1</p></x>');
  t('count(css(''foo''))', '3', '');
  t('count(css(''p:empty''))', '1', '');
  t('count(css(''foo:empty''))', '0', '');

  t('string-join(css(''*:link''), ",")', 'a2,a3', '<x><a>a1</a><p>p1</p><a href>a2</a><a href="foobar">a3</a><a>a4</a></x>');

  t('string-join(css(''*:not(:link)''), ",")', 'a1p1a2a3a4,a1,p1,a4', '');
  t('string-join(css(''*:link:not(:link)''), ",")', '', '');
  t('string-join(css(''a''), ",")', 'a1,a2,a3,a4', '');
  t('string-join(css(''a:not(a)''), ",")', '', '');
  t('string-join(css(''a:not([href=""])''), ",")', 'a1,a3,a4', ''); //confirmed with firefox/chrome
  t('string-join(css(''a:not([href])''), ",")', 'a1,a4', ''); //confirmed with firefox/chrome
  t('string-join(css(''*:not(a)''), ",")', 'a1p1a2a3a4,p1', '');
  t('string-join(css(''*:not(x)''), ",")', 'a1,p1,a2,a3,a4', '');
  t('string-join(css(''*:not(x):not(a)''), ",")', 'p1', '');


  t('string-join(css(''h1 em''), ",")', 'very,a', '<h1>This <span class="myclass">headline is <em>very</em> important</span><em>a</em></h1>');
  t('string-join(css(''h1 * em''), ",")', 'very', '');
  t('string-join(css(''h1 > em''), ",")', 'a', '');

  t('string-join(css(''*[lang|=fr]''), ",")', 'BJe suis français.', '<body lang=fr>B<p>Je suis français.</p></body>');
  t('string-join(css(''[lang|=fr]''), ",")', 'BJe suis français.', '');
  t('string-join(css(''*:lang(fr)''), ",")', 'BJe suis français.,Je suis français.', '');
  t('string-join(css('':lang(fr)''), ",")', 'BJe suis français.,Je suis français.', '');
  t('string-join(css(''*:lang(  fr  )''), ",")', 'BJe suis français.,Je suis français.', '');
  t('string-join(css('':lang(  fr  )''), ",")', 'BJe suis français.,Je suis français.', '');
  t('string-join(css(''*:lang(de)''), ",")', '', '');
  t('string-join(css('':lang(de)''), ",")', '', '');

  t('string-join(css(''div * p''), ",")', 'A3A4P2', '<div><p><a>A1</a><a href="x">A2</a>P1</p><span><p><a>A3</a><a href="qw">A4</a>P2</p></span><p>P3<a>A5</a><a href="qwq">A6</a></p></div>');
  t('string-join(css(''div p *[href]''), ",")', 'A2,A4,A6', '');
  t('string-join(css(''div > p *[href]''), ",")', 'A2,A6', '');
  t('string-join(css(''div>p *[href]''), ",")', 'A2,A6', '');
  t('string-join(css(''div>*>p *[href]''), ",")', 'A4', '');


  t('string-join(css(''body > p''), ",")', 'P0,P3', '<body><p>P0</p><div><ol><li><p>P!</p></li><div><li><p>pppp</p></li></div></ol><p>P2</p></div><P>P3</p></body>');
  t('string-join(css(''body'#9'p''), ",")', 'P0,P!,pppp,P2,P3', '');
  t('string-join(css(''div ol>li p''), ",")', 'P!', '');

  t('string-join(css(''math + p''), ",")', 'P0,P1', '<math>M0</math><p>P0</p><x><math>M1</math><p>P1</p><math>M2</math><div/><p>P2</p><math>M3</math></x><p>P3</p>');
  t('string-join(css(''math ~ p''), ",")', 'P0,P1,P2,P3', '');
  t('string-join(css(''math + p''), ",")', 'P0,P1,P2', '<math>M0</math><p>P0</p><x><math>M1</math><p>P1</p><math>M2</math>xxxx<p>P2</p><math>M3</math></x><p>P3</p>');
  t('string-join(css(''math + p''), ",")', 'P1', '<x><math>M1</math><p>P1</p><math>M2</math><div/><p>P2</p><math>M3</math></x><p>P3</p>');
  t('string-join(css(''math ~ p''), ",")', 'P1,P2', '');


  t('string-join(css(''h1.opener + h2''), ",")', 'h2ba', '<html><h1 class="x">h1a</h1><h2>h2aa</h2><h2>h2ab</h2><h1 class="opener">h1b</h1><h2>h2ba</h2><h2>h2bb</h2></html>');
  t('string-join(css(''h1.opener + h2''), ",")', 'h2ba', '<html>..<h1 class="x">h1a</h1>..<h2>h2aa</h2>..<h2>h2ab</h2>..<h1 class="opener">h1b</h1>..<h2>h2ba</h2>..<h2>h2bb</h2>..</html>');


  t('string-join(css(''h1 ~ pre''), ",")', 'function a(x) = 12x/13.5', '<h1>Definition of the function a</h1><p>Function a(x) has to be applied to all figures in the table.</p><pre>function a(x) = 12x/13.5</pre>');
  t('string-join(css(''h1 + pre''), ",")', '', '');
  t('string-join(css(''h1 > pre''), ",")', '', '');



  t('string-join(css(''blockquote div > p''), ",")', 'This text should be green.', '<blockquote><div><div><p>This text should be green.</p></div></div></blockquote>'); //89

  t('string-join(css(''p''), ",")', 'This line should have a green background.', '  <p title="hello world">This line should have a green background.</p>'); //7b
  t('string-join(css(''[title~="hello world"]''), ",")', '', '');

  t('string-join(css(''p[class~="b"]''), ",")', 'This paragraph should have green background because CLASS contains b', '<p class="a b c">This paragraph should have green background because CLASS contains b</p><address title="tot foo bar"><span class="a c">This address should also</span>  <span class="a bb c">have green background because the selector in the last rule does not apply to the inner SPANs.</span></address>');
  t('string-join(css(''address[title~="foo"]''), ",")', 'This address should alsohave green background because the selector in the last rule does not apply to the inner SPANs.', '');
  t('string-join(css(''span[class~="b"] ''), ",")', '', '');

  t('string-join(css(''a,c''), ",")', '1,3,1b', '<x><a>1</a><b>2</b><c>3</c><a>1b</a><b>2b</b></x>');
  t('string-join(css(''a,c,b''), ",")', '1,2,3,1b,2b', '');
  t('string-join(css(''a , c''), ",")', '1,3,1b', '');
  t('string-join(css(''a, c''), ",")', '1,3,1b', '');
  t('string-join(css(''a ,c''), ",")', '1,3,1b', '');
  t('string-join(css('',a''), ",")', '', '');
  t('string-join(css(''a,''), ",")', '1,1b', ''); //TODO: how to handle invalid selectors?
  t('string-join(css('',a,''), ",")', '', '');


  //form extension method
  t('', '', '!<html><form action="abc" method="POST"><input name="foo" value="bar"/><input name="X" value="123" type="unknown"/><input name="Y" value="456" type="checkbox" checked/><input name="Z" value="789" type="checkbox"/></form>'
                + '<form action="abc22"><input name="foo2" value="bar2"/><input name="X" value="123" type="unknown"/><input name="Y" value="456" type="checkbox" checked/><input name="Z" value="789" type="checkbox"/></form>'
                + '<form action="next/haus/bimbam?k=y"><input name="T" value="Z"/><textarea name="fy">ihl</textarea></form>'
                + '</html>');
  t('form(//form[1]).url', 'pseudo://test/abc', '');
  t('form(//form[1]).method', 'POST', '');
  t('form(//form[1]).post', 'foo=bar&Y=456', '');
  t('form(//form[1], "foo=override").post', 'foo=override&Y=456', '');
  t('form(//form[1], "Y=override2&Z=override3&Z=override4").post', 'foo=bar&Y=override2&Z=override3&Z=override4', '');
  t('form(//form[1], "foo=override&Y=override2&Z=override3&Z=override4").post', 'foo=override&Y=override2&Z=override3&Z=override4', '');

  t('form(//form[2]).url', 'pseudo://test/abc22?foo2=bar2&Y=456', '');
  t('form(//form[2]).method', 'GET', '');
  t('form(//form[2]).post', '', '');
  t('form(//form[2], "tt=tttt").url', 'pseudo://test/abc22?foo2=bar2&Y=456&tt=tttt', '');
  t('form(//form[2], ("tt=tttt", "foo2=maus")).url', 'pseudo://test/abc22?foo2=maus&Y=456&tt=tttt', '');

  t('count(form(//form))', '3', '');
  t('form(//form)[1].url', 'pseudo://test/abc', '');
  t('form(//form)[2].url', 'pseudo://test/abc22?foo2=bar2&Y=456', '');
  t('form(//form)[3].url', 'pseudo://test/next/haus/bimbam?k=y&T=Z&fy=ihl', '');

  t('form(//form).url', 'abs://hallo?abc=cba', '!<html><form action="abs://hallo"><input name="abc" value="cba"/></form></html>');
  t('form(//form).url', 'abs://foo/bar?abcdef=on', '!<html><form action="abs://foo/bar"><input name="abcdef" type="checkbox" checked/></form></html>');

  //Newer tests (the older tests as array is a usability catastrophe, no backtrace, no breakpoints, no easy adding... )

  //test attributes as nodes
  t('', '', '!<test><a att1="v1" att2="v2" att3="v3" att4="v4" foo="bar">a node</a>TEST</test>');
  t('count(//a/@*)', '5', '');
  t('(//a/@*/..)', 'a node', '');
  t('(//a/@*/../@att1)', 'v1', '');
  t('(//a/@*/../@att1/..)', 'a node', '');
  t('(//a/@*/../attribute::att2/..)', 'a node', '');
  t('(//a/@*[node-name(.) = "att2"])', 'v2', '');
  t('(//a/@*[local-name() = "att3"])', 'v3', '');
  t('(//a/@*[local-name(.) = "att4"])', 'v4', '');
  t('(//a/@*[name(.) = "att1"])', 'v1', '');

  t('string-join(//a/@att2/descendant::*, ",")', '', '');
  t('string-join(//a/@att2/attribute::*, ",")', '', '');
  t('string-join(//a/@att2/self::*, ",")', 'v2', '');
  t('string-join(//a/@att2/descendant-or-self::*, ",")', 'v2', '');
  t('string-join(//a/@att2/following-sibling::*, ",")', '', '');
  t('string-join(//a/@att2/following::*, ",")', '', '');

  t('string-join(//a/@att2/parent::*, ",")', 'a node', '');
  t('string-join(//a/@att2/ancestor::*, ",")', 'a nodeTEST,a node', '');
  t('string-join(//a/@att2/preceding-sibling::*, ",")', '', '');
  t('string-join(//a/@att2/preceding::*, ",")', '', '');
  t('string-join(//a/@att2/ancestor-or-self::*, ",")', 'a nodeTEST,a node,v2', '');

  t('string-join(//@*, ",")', 'xyz', '!<a init="xyz"><?foobar maus="123" haus="456"?></a>');
  t('string-join(//processing-instruction(), ",")', 'maus="123" haus="456"', '');
  t('string-join(//processing-instruction(), ",")', '  maus="123" haus="456"    ', '!<a init="xyz"><?foobar   maus="123" haus="456"    ?></a>');

  //Int 65 math
  t('9223372036854775807 + 1', '9223372036854775808', '');
  t('9223372036854775807 - 1', '9223372036854775806', '');
  t('9223372036854775808 - 1', '9223372036854775807', '');
  t('18446744073709551615', '18446744073709551615', '');
  t('9223372036854775807 - 18446744073709551615', '-9223372036854775808', '');
  t('- 18446744073709551615', '-18446744073709551615', '');
  t('int(5)' ,'5', '');
  t('type-of(xs:decimal(6) idiv xs:integer(2))', 'integer', '');
  t('min((-9223372036854775807, 9223372036854775807))', '-9223372036854775807', '');
  t('max((-9223372036854775807, 9223372036854775807))', '9223372036854775807', '');
  t('min((-18446744073709551615, 18446744073709551615))', '-18446744073709551615', '');
  t('max((-18446744073709551615, 18446744073709551615))', '18446744073709551615', '');

  t('string-join(//b, ",")', 'A,B,C', '!<a take="1"><b id="1">A</b><b id="2">B</b><b id="3">C</b></a>');
  t('string-join(//b[@id=/a/@take], ",")', 'B', '!<a take="2"><b id="1">A</b><b id="2">B</b><b id="3">C</b></a>');
  t('string-join(//b[/a/@take=@id], ",")', 'B', '!<a take="2"><b id="1">A</b><b id="2">B</b><b id="3">C</b></a>');

  //some namespaces
  t('string-join(/r/b, ",")',   'xB', '!<r><a:b>AB</a:b><b>xB</b><a:c>AC</a:c><b:a>BA</b:a><b:b>BB</b:b></r>');
  t('string-join(/r/a:b, ",")', 'AB', '');
  t('string-join(/r/b:b, ",")', 'BB', '');
  t('string-join(/r/*:b, ",")', 'AB,xB,BB', '');
  t('string-join(/r/b:*, ",")', 'BA,BB', '');
  t('string-join(/r/a:*, ",")', 'AB,AC', '');
  t('string-join(/r/a, ",")', '', '');
  t('string-join(/r/*:a, ",")', 'BA', '');
  t('string-join(/r/*, ",")', 'AB,xB,AC,BA,BB', '');
  t('string-join(/r/element(), ",")', 'AB,xB,AC,BA,BB', '');
  t('string-join(/r/element(*), ",")', 'AB,xB,AC,BA,BB', '');
  t('string-join(/r/element(a:b), ",")', 'AB', '');

  t('string-join(/r/child::b, ",")', 'xB', '');
  t('string-join(/r/child::a:b, ",")', 'AB', '');
  t('string-join(/r/child::b:b, ",")', 'BB', '');
  t('string-join(/r/child::*:b, ",")', 'AB,xB,BB', '');
  t('string-join(/r/child::b:*, ",")', 'BA,BB', '');
  t('string-join(/r/child::a:*, ",")', 'AB,AC', '');
  t('string-join(/r/child::a, ",")', '', '');
  t('string-join(/r/child::*:a, ",")', 'BA', '');
  t('string-join(/r/child::*, ",")', 'AB,xB,AC,BA,BB', '');
  t('string-join(/r/child::element(), ",")', 'AB,xB,AC,BA,BB', '');
  t('string-join(/r/child::element(*), ",")', 'AB,xB,AC,BA,BB', '');
  t('string-join(/r/child::element(a:b), ",")', 'AB', '');

  t('string-join(/r/b, ",")',   '', '!<r a:b="AB" b="xB" a:c="AC" b:a="BA" b:b="BB"/>');
  t('string-join(/r/a:b, ",")', '', '');
  t('string-join(/r/@b, ",")',   'xB', '');
  t('string-join(/r/@a:b, ",")',   'AB', '');
  t('string-join(/r/@b:b, ",")', 'BB', '');
  t('string-join(/r/@*:b, ",")', 'AB,xB,BB', '');
  t('string-join(/r/@b:*, ",")', 'BA,BB', '');
  t('string-join(/r/@a:*, ",")', 'AB,AC', '');
  t('string-join(/r/@a, ",")', '', '');
  t('string-join(/r/@*:a, ",")', 'BA', '');
  t('string-join(/r/@*, ",")', 'AB,xB,AC,BA,BB', '');

  t('string-join(/r/attribute::b, ",")',   'xB', '');
  t('string-join(/r/attribute::a:b, ",")',   'AB', '');
  t('string-join(/r/attribute::b:b, ",")', 'BB', '');
  t('string-join(/r/attribute::*:b, ",")', 'AB,xB,BB', '');
  t('string-join(/r/attribute::b:*, ",")', 'BA,BB', '');
  t('string-join(/r/attribute::a:*, ",")', 'AB,AC', '');
  t('string-join(/r/attribute::a, ",")', '', '');
  t('string-join(/r/attribute::*:a, ",")', 'BA', '');
  t('string-join(/r/attribute::*, ",")', 'AB,xB,AC,BA,BB', '');

  t('string-join(/r/attribute(), ",")', 'AB,xB,AC,BA,BB', '');
  t('string-join(/r/attribute(*), ",")', 'AB,xB,AC,BA,BB', '');
  t('string-join(/r/attribute(a:b), ",")', 'AB', '');
  t('string-join(/r/attribute::attribute(), ",")', 'AB,xB,AC,BA,BB', '');
  t('string-join(/r/attribute::attribute(*), ",")', 'AB,xB,AC,BA,BB', '');
  t('string-join(/r/attribute::attribute(a:b), ",")', 'AB', '');

  t('string-join(for $i in (1, 2), $j in (3, 4) return ($i, $j), ":")', '1:3:1:4:2:3:2:4');

  //More failed XQTS tests
  //t('xs:untypedAtomic("-10000000") cast as xs:float', '-10000000', ''); this is an fpc bug! (22567)
  t('1*/', '3', '!<a><b>0</b><b>0</b><b>3</b></a>');
  t('/a/b[1*/]', '3', '');
  t('/a/b[-1+/]', '0', '');
  t('xs:long("-92233720368547758") idiv xs:long("-92233720368547758")', '1', '');
  t('xs:long("92233720368547758") idiv xs:long("-92233720368547758")', '-1', '');
  t('xs:long("-92233720368547758") idiv xs:long("92233720368547758")', '-1', '');
  t('xs:long("92233720368547758") idiv xs:long("92233720368547758")', '1', '');
  t('string-join(92233720368547757 to 92233720368547759, ":")', '92233720368547757:92233720368547758:92233720368547759', '');
  t('string-join(-92233720368547759 to -92233720368547757, ":")', '-92233720368547759:-92233720368547758:-92233720368547757', '');
  t('string-join(-3 to 3, ":")', '-3:-2:-1:0:1:2:3', '');
  t('ceiling(1.5e20)', '1.5E20');
  t('fn:ceiling(xs:float("-3.4028235E38"))', '-3.4028235E38');
  t('fn:ceiling(xs:float("-3.4028235E38")) instance of xs:float', 'true');
  t('fn:floor(xs:float("-3.4028235E38"))', '-3.4028235E38');
  t('fn:abs(xs:float("-3.4028235E38"))', '3.4028235E38');
  t('fn:abs(xs:float("-3.4028235E38"))', '3.4028235E38');
  t('fn:round(xs:float("-3.4028235E38"))', '-3.4028235E38');
  t('fn:round-half-to-even(xs:float("-3.4028235E38"))', '-3.4028235E38');
  t('fn:round-half-to-even(10, 0)', '10');
  t('fn:round-half-to-even(10, -1)', '10');
  t('fn:round-half-to-even(14, -1)', '10');
  t('fn:round-half-to-even(15, -1)', '20');
  t('fn:round-half-to-even(24, -1)', '20');
  t('fn:round-half-to-even(25, -1)', '20');
  t('fn:round-half-to-even(26, -1)', '30');
  t('fn:round-half-to-even(124, -1)', '120');
  t('fn:round-half-to-even(125, -1)', '120');
  t('fn:round-half-to-even(126, -1)', '130');
  t('fn:round-half-to-even(-124, -1)', '-120');
  t('fn:round-half-to-even(-125, -1)', '-120');
  t('fn:round-half-to-even(-126, -1)', '-130');
  t('fn:round-half-to-even(126, 1)', '126');
  t('fn:round-half-to-even(-126, 1)', '-126');
  t('fn:round-half-to-even(10, -2)', '0');
  t('fn:round-half-to-even(10.3, -5000)', '0');
  t('fn:round-half-to-even(10.3, 5000)', '10.3');
  t('fn:round-half-to-even(10.3, -999999999999)', '0');
  t('fn:round-half-to-even(10.3, 999999999999)', '10.3');
  t('fn:round-half-to-even(10, -2)', '0');
  t('fn:round-half-to-even(xs:float("3.4028235E38"), -38)', '3E38');
  t('fn:round-half-to-even(xs:float("-3.4028235E38"), -38)', '-3E38');
  t('fn:round-half-to-even(xs:double("3.4028235E38"), -38)', '3E38');
  t('fn:round-half-to-even(xs:double("-3.4028235E38"), -38)', '-3E38');
  t('fn:round-half-to-even(xs:double("3.5E38"), -38)', '4E38');
  t('fn:round-half-to-even(xs:double("-3.5E38"), -38)', '-4E38');
  t('fn:round-half-to-even(10.344, 2)', '10.34');
  t('fn:round-half-to-even(10.345, 2)', '10.34');
  t('fn:round-half-to-even(10.346, 2)', '10.35');
  t('fn:round-half-to-even(10.354, 2)', '10.35');
  t('fn:round-half-to-even(10.355, 2)', '10.36');
  t('fn:round-half-to-even(10.356, 2)', '10.36');
  t('fn:round-half-to-even(-10.344, 2)', '-10.34');
  t('fn:round-half-to-even(-10.345, 2)', '-10.34');
  t('fn:round-half-to-even(-10.346, 2)', '-10.35');
  t('fn:round-half-to-even(-10.354, 2)', '-10.35');
  t('fn:round-half-to-even(-10.355, 2)', '-10.36');
  t('fn:round-half-to-even(-10.356, 2)', '-10.36');
  t('fn:round(xs:nonNegativeInteger("303884545991464527"))', '303884545991464527');



  performUnitTest('$abc','alphabet','');
  performUnitTest('$ABC','','');
  vars.caseSensitive:=false;
  performUnitTest('$abc','alphabet','');
  performUnitTest('$ABC','alphabet','');
  vars.caseSensitive:=true;
  performUnitTest('$abc','alphabet','');
  performUnitTest('$ABC','','');


  xml.parseTree('<?xml encoding="utf-8"?><html/>'); if xml.getLastTree.getEncoding <> eUTF8 then raise Exception.Create('xml encoding detection failed 1');
  xml.parseTree('<?xml encoding="windows-1252"?><html/>'); if xml.getLastTree.getEncoding <> eWindows1252 then raise Exception.Create('xml encoding detection failed 2');
  xml.parseTree('<?xml encoding="utf-8" foo="bar"?><html/>'); if xml.getLastTree.getEncoding <> eUTF8 then raise Exception.Create('xml encoding detection failed 3');
  xml.parseTree('<?xml encoding="windows-1252" foo="bar"?><html/>'); if xml.getLastTree.getEncoding <> eWindows1252 then raise Exception.Create('xml encoding detection failed 4');

  ps.free;
  xml.Free;
  vars.Free;
end;


end.
