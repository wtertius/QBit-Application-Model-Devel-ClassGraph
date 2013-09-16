package QBit::Application::Model::Devel::ClassGraph;

use qbit;

use base qw(QBit::Application::Model);

use QBit::GraphViz;

sub _get_all_packages {
    my ($self, $ns) = @_;

    $ns ||= '';

    my $_ns = $ns || 'main::';
    my @packages = eval qq(keys %${_ns});
    @packages = grep {!/main|SUPER|strict|<none>/} grep {$_ =~ s/::$//} @packages;

    foreach my $package (@packages) {
        my $full_pkg_name = "$ns$package";
        $self->{'__PACKAGES__'}{$full_pkg_name} = {
            isa => eval('\@' . $full_pkg_name . '::ISA'),
            (
                eval {$full_pkg_name->isa('QBit::Application')}
                ? (models => package_stash($full_pkg_name)->{'__MODELS__'},)
                : ()
            ),
          }
          if ($full_pkg_name =~ /^QBit::/
            || eval {$full_pkg_name->isa('QBit::Class') || $full_pkg_name->isa('Exception')})
          && $full_pkg_name !~ /::ISA::CACHE$/;
        $self->_get_all_packages("${full_pkg_name}::");
    }
}

sub _draw_packages {
    my ($self, $g) = @_;

    my %clusters;
    foreach my $package (keys %{$self->{'__PACKAGES__'}}) {
        my $cluster = $package;
        $cluster = $cluster =~ /^([\w\d]+::)/ ? $1 : '';

        $clusters{$cluster} ||= {
            name  => $cluster,
            style => 'filled',
            color => 'AliceBlue',
        };

        my $color = join(',', rand, rand, 0.7);
        $self->{'__PACKAGES__'}{$package}{'color'} = $color;

        $g->add_node(
            $package,
            shape => eval {$package->isa('QBit::Application')} ? 'octagon'
            : eval {$package->isa('QBit::Application::Model')}       ? 'diamond'
            : eval {$package->isa('QBit::WebInterface::Controller')} ? 'hexagon'
            : eval {$package->isa('Exception')}                      ? 'trapezium'
            : 'ellipse',
            cluster   => $clusters{$cluster},
            label     => $package,
            color     => $color,
            fontcolor => $color,
        );
    }

    foreach my $package (keys %{$self->{'__PACKAGES__'}}) {
        foreach my $isa_package (@{$self->{'__PACKAGES__'}{$package}{isa}}) {
            $g->add_edge(
                $isa_package => $package,
                dir          => 'back',
                arrowtail    => 'onormal',
                minlen       => 2,
                color        => $self->{'__PACKAGES__'}{$package}{'color'},
                fontcolor    => $self->{'__PACKAGES__'}{$package}{'color'},
            );
        }
        while (my ($accessor, $model_package) = each(%{$self->{'__PACKAGES__'}{$package}{models} || {}})) {
            $g->add_edge(
                $package  => $model_package,
                label     => $accessor,
                dir       => 'forward',
                style     => 'dashed',
                color     => $self->{'__PACKAGES__'}{$package}{'color'},
                fontcolor => $self->{'__PACKAGES__'}{$package}{'color'},
            );
        }
    }

}

sub get_graph {
    my ($self) = @_;

    my $g = QBit::GraphViz->new(
        rankdir => 0,
        overlap => 'false',
        node    => {
            fontsize => 10,
            color    => 'black',
        }
    );

    $self->{'__PACKAGES__'} = {};

    $self->_get_all_packages();
    $self->_draw_packages($g);

    return $g;
}

TRUE;
