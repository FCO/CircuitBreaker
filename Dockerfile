FROM    rakudo-star

COPY    META6.json /root
WORKDIR /root
RUN     PERL6_TEST_META=1 PERL6LIB=$PWD/lib zef install . --depsonly
COPY    . /root
