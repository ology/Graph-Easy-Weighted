package Graph::Easy::Weighted;

# ABSTRACT: A weighted graph implementation

our $VERSION = '0.0501';

use warnings;
use strict;

use parent qw(Graph::Easy);

use Carp qw( croak );
use Readonly;
Readonly my $WEIGHT => 'weight';

=head1 SYNOPSIS

 use Graph::Easy::Weighted;

 my $gw = Graph::Easy::Weighted->new();
 $gw->populate(
    [ [0,1,2,0,0], # Vertex 0 with 2 edges of weight 3
      [1,0,3,0,0], #    "   1      2 "               4
      [2,3,0,0,0], #    "   2      2 "               5
      [0,0,1,0,0], #    "   3      1 "               1
      [0,0,0,0,0], #    "   4      0 "               0
    ]
 );
 for my $vertex ( $gw->vertices ) {
    printf "vertex: %s weight=%.2f\n",
        $vertex->name, $gw->get_cost($vertex);
    for my $edge ( $gw->edges ) {
        next if $edge->from->name ne $vertex->name;
        printf "\tedge to: %s weight=%.2f\n",
            $edge->to->name, $gw->get_cost($edge);
    }
 }

 my ($lightest, $heaviest) = $gw->vertex_span();
 ($lightest, $heaviest) = $gw->edge_span();

 my $weight = $gw->path_cost(\@vertices);

 my $attr = 'probability';
 $gw = Graph::Easy::Weighted->new();
 $gw->populate(
    {
        0 => { attributes => { title => 'A' }, 1=>0.4, 3=>0.6 },
        1 => { attributes => { title => 'B' }, 0=>0.3, 2=>0.7 },
        2 => { attributes => { title => 'C' }, 0=>0.5, 2=>0.5 },
        3 => { attributes => { title => 'D' }, 0=>0.2, 1=>0.8 },
    },
    $attr,
    '%0.2f'
 );
 for my $vertex ( $gw->vertices ) {
    printf "%s vertex: %s %s=%s\n",
        $vertex->title, $vertex->name, $attr, $gw->get_cost($vertex, $attr);
    for my $edge ( $gw->edges ) {
        next if $edge->from->name ne $vertex->name;
        printf "\tedge to: %s %s=%s\n",
            $edge->to->name, $attr, $gw->get_cost($edge, $attr);
    }
 }

=head1 DESCRIPTION

A C<Graph::Easy::Weighted> object is a subclass of the L<Graph::Easy> module
with attribute handling.  As such, all of the L<Graph::Easy> methods may be used
as documented, but with the addition of custom weighting.

=head1 METHODS

=head2 new()

  my $gw = Graph::Easy::Weighted->new;

Return a new C<Graph::Easy::Weighted> object.

Please see L<Graph::Easy/new()> for the possible constructor arguments.

=head2 populate()

  $gw->populate($matrix);
  $gw->populate($matrix, $attribute);
  $gw->populate(\@vectors);
  $gw->populate(\@vectors, $attribute);
  $gw->populate(\%data);
  $gw->populate(\%data, $attribute);
  $gw->populate(\%data, $attribute, $format);

Populate a graph with weighted nodes.

The data can be an arrayref of numeric vectors, a C<Math::MatrixReal> object, or
a hashref of numeric edge values.

Data given as a hash reference may contain node attributes as shown in the
SYNOPSIS.  See L<Graph::Easy::Manual> for the available attributes.

The optional edge C<attribute> argument is a string, with the default "weight."

Multiple attributes may populate a single graph, thereby layering and increasing
the overall dimension.

An optional C<sprintf> format string may be provided for the edge label.

Examples of vertices in array reference form:

  []      1 vertex with no edges.
  [0]     1 vertex with no edges.
  [1]     1 vertex and 1 edge to itself, weight 1.
  [0,1]   2 vertices and 1 edge, weight 1.
  [1,0,9] 3 vertices and 2 edges having, weight 10.
  [1,2,3] 3 vertices and 3 edges having, weight 6.

=cut

sub populate {
    my ($self, $data, $attr, $format) = @_;

    # Set the default attribute.
    $attr ||= $WEIGHT;

    # What type of data are we given?
    my $data_ref = ref $data;

    if ($data_ref eq 'ARRAY' || $data_ref eq 'Math::Matrix') {
        my $vertex = 0;
        for my $neighbors (@$data) {
            $self->_from_array( $vertex, $neighbors, $attr, $format );
            $vertex++;
        }
    }
    elsif ($data_ref eq 'HASH') {
        for my $vertex (keys %$data) {
            if ( $data->{$vertex}{attributes} ) {
                my $attributes = delete $data->{$vertex}{attributes};
                for my $attr ( keys %$attributes ) {
                    $self->set_vertex_attribute($vertex, $attr, $attributes->{$attr});
                }
            }
            $self->_from_hash( $vertex, $data->{$vertex}, $attr, $format );
        }
    }
    else {
        croak "Unknown data type: $data\n";
    }
}

sub _from_array {
    my ($self, $vertex, $neighbors, $attr, $format) = @_;

    my $vertex_weight = 0;

    for my $n (0 .. @$neighbors - 1) {
        my $w = $neighbors->[$n]; # Weight of the edge to the neighbor.
        next unless $w;

        my $edge = Graph::Easy::Edge->new();
        $edge->set_attributes(
            {
                label     => $format ? sprintf( $format, $w ) : $w,
                "x-$attr" => $w,
            }
        );

        $self->add_edge($vertex, $n, $edge);

        $vertex_weight += $w;
    }

    $self->set_vertex_attribute($vertex, "x-$attr", $vertex_weight);
}

sub _from_hash {
    my ($self, $vertex, $neighbors, $attr, $format) = @_;

    my $vertex_weight = 0;

    for my $n (keys %$neighbors) {
        my $w = $neighbors->{$n}; # Weight of the edge to the neighbor.

        my $edge = Graph::Easy::Edge->new();
        $edge->set_attributes(
            {
                label     => $format ? sprintf( $format, $w ) : $w,
                "x-$attr" => $w,
            }
        );

        $self->add_edge($vertex, $n, $edge);

        $vertex_weight += $w;
    }

    $self->set_vertex_attribute($vertex, "x-$attr", $vertex_weight);
}

=head2 get_cost()

  $c = $gw->get_cost($vertex);
  $c = $gw->get_cost($vertex, $attribute);
  $c = $gw->get_cost($edge);
  $c = $gw->get_cost($edge, $attribute);

Return the weight or named attribute value for the vertex or edge.

=cut

sub get_cost {
    my ($self, $v, $attr) = @_;
    croak 'ERROR: No vertex given to get_cost()' unless defined $v;

    $attr ||= $WEIGHT;

    if ( ref $v eq 'Graph::Easy::Edge' ) {
        return $v->get_custom_attributes->{"x-$attr"} || 0;
    }

    return $self->get_vertex_attribute($v->name, "x-$attr") || 0;
}

=head2 vertex_span()

 my ($lightest, $heaviest) = $gw->vertex_span();
 my ($lightest, $heaviest) = $gw->vertex_span($attr);

Return the lightest and heaviest vertices.

=cut

sub vertex_span {
    my ($self, $attr) = @_;

    my $mass = {};
    for my $vertex ( $self->vertices ) {
        $mass->{$vertex->name} = $self->get_cost($vertex, $attr);
    }

    my ($smallest, $biggest);
    for my $vertex ( keys %$mass ) {
        my $current = $mass->{$vertex};
        if ( !defined $smallest || $smallest > $current ) {
            $smallest = $current;
        }
        if ( !defined $biggest || $biggest < $current ) {
            $biggest = $current;
        }
    }

    my ($lightest, $heaviest) = ([], []);
    for my $vertex ( keys %$mass ) {
        push @$lightest, $vertex if $mass->{$vertex} == $smallest;
        push @$heaviest, $vertex if $mass->{$vertex} == $biggest;
    }

    return $lightest, $heaviest;
}

=head2 edge_span()

 my ($lightest, $heaviest) = $gw->edge_span();
 my ($lightest, $heaviest) = $gw->edge_span($attr);

Return the lightest to heaviest edges.

=cut

sub edge_span {
    my ($self, $attr) = @_;

    my $mass = {};
    for my $edge ( $self->edges ) {
        $mass->{ $edge->from->name . '_' . $edge->to->name } = $self->get_cost($edge, $attr);
    }

    my ($smallest, $biggest);
    for my $edge ( keys %$mass ) {
        my $current = $mass->{$edge};
        if ( !defined $smallest || $smallest > $current ) {
            $smallest = $current;
        }
        if ( !defined $biggest || $biggest < $current ) {
            $biggest = $current;
        }
    }

    my ($lightest, $heaviest) = ([], []);
    for my $edge ( sort keys %$mass ) {
        my $arrayref = [ split /_/, $edge ];
        push @$lightest, $arrayref if $mass->{$edge} == $smallest;
        push @$heaviest, $arrayref if $mass->{$edge} == $biggest;
    }

    return $lightest, $heaviest;
}


=head2 path_cost()

 my $weight = $gw->path_cost(\@named_vertices);
 my $weight = $gw->path_cost(\@named_vertices, $attr);

Return the summed weight (or given cost attribute) of the path edges.

For shortest paths and minimum spanning trees, please see
L<Graph::Weighted/EXAMPLES>.

=cut

sub path_cost {
    my ($self, $path, $attr) = @_;

    my $path_cost = 0;

    for my $i ( 0 .. @$path - 2 ) {
        my $edge = $self->edge( $path->[$i], $path->[ $i + 1 ] );
        next unless $edge;
        $path_cost += $self->get_cost( $edge, $attr );
    }

    return $path_cost;
}

1;
__END__

=head1 SEE ALSO

L<Graph::Easy>, the parent of this module

L<Graph::Weighted>, the sibling

The F<eg/*> and F<t/*> file sources

=cut
