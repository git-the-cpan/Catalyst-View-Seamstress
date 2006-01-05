package Catalyst::View::Seamstress;

use strict;
# [10:05:57] <@andyg> Catalyst::View is the correct base class
use base qw/Catalyst::View/; 
#use base qw/Catalyst::Base/;
use NEXT;


our ($VERSION) = ('$Revision: 1.10 $' =~ m/([\.\d]+)/) ;


=head1 NAME

Catalyst::View::Seamstress - HTML::Seamstress View Class for Catalyst

=head1 SYNOPSIS

# use the helper to create MyApp::View::Seamstress
# where comp_root and skeleton are optional

    myapp_create.pl view Seamstress Seamstress /path/to/html html::skeleton
                         ^-modulenm ^-helpernm ^-comp_root   ^-skeleton

# optionally edit the skeleton and meat_pack routines
# in lib/MyApp/View/Seamstress.pm

# render view from lib/MyApp.pm or lib/MyApp::C::SomeController.pm

    sub message : Global {
        my ( $self, $c ) = @_;

        $c->stash->{template} = 'html::hello_world';
        $c->stash->{name}     = 'Mister GreenJeans';
        $c->stash->{date}     = 'Today';

        # the DefaultEnd plugin would mean no need for this line
        $c->forward('MyApp::View::Seamstress');
    }


=head1 DESCRIPTION

This is the Catalyst view class for L<HTML::Seamstress|HTML::Seamstress>.
Your application should define a view class which is a subclass of
this module.  The easiest way to achieve this is using the
F<myapp_create.pl> script (where F<myapp> should be replaced with
whatever your application is called).  This script is created as part
of the Catalyst setup.

    $ script/myapp_create.pl view Seamstress Seamstress

This creates a MyApp::View::Seamstress.pm module in the 
F<lib> directory (again, replacing C<MyApp> with the name of your
application).


Now you can modify your action handlers in the main application and/or
controllers to forward to your view class.  You might choose to do this
in the end() method, for example, to automatically forward all actions
to the Seamstress view class.

    # In MyApp or MyApp::Controller::SomeController
    
    sub end : Private {
        my( $self, $c ) = @_;
        $c->forward('MyApp::View::Seamstress');
    }

Or you might like to use 
L<Catalyst::Plugin::DefaultEnd|Catalyst::Plugin::DefaultEnd>


=head1 CONFIGURATION

The helper app automatically puts the per-application
configuration info in C<MyApp::View::Seamstress>.

=head2 RENDERING VIEWS

=head1 The meat-skeleton paradigm

When Catalyst::View::Seamstress is forwarded to, it can be used in 3
ways depending on how the stash and the View config variables are set
at that time. 

HTML pages typically have meat and a skeleton. The meat varies from page
to page while the skeleton is fairly (though not completely) 
static. For example, the skeleton of a webpage is usually a header, a
footer, and a navbar. The meat is what shows up when you click on a
link on the page somewhere. While the meat will change with each
click, the skeleton is rather static.

The perfect example of 

Mason accomodates the meat-skeleton paradigm via
an C<autohandler> and C<< $m->call_next() >>. Template 
accomodates it via its C<WRAPPER> directive.

And Seamstress? Well, here's what you _can_ do:

=over

=item 1 generate the meat, C<$meat>

This is typically what you see in the C<body> part of an HTML page

=item 2 generate the skeleton, C<$skeleton>

This is typically the html, head, and maybe some body 

=item 3 put the meat in the skeleton

=back

So, nothing about this is forced. This is just how I typically do
things and that is why
L<Catalyst::View::Seamstress|Catalyst::View::Seamstress> has support
for this.



There are two items which control how this plugin renders HTML.

=over

=item * C<< $c->stash->{template} >>

The Seamstress view plugin MUST have a template
to work on or it
will balk with an error:

    sub message : Global {
        my ( $self, $c ) = @_;
        $c->stash->{template} = 'html::hello_world';
        $c->stash->{name}     = 'Billy Bob';
        $c->stash->{date}     = 'medjool sahara';
        $c->forward('MyApp::View::Seamstress');
    }

To be honest, Seamstress does not alter the HTML it unrolls, so the word
"template" is really not accurate. But since all the other View classes
adopted that place in the stash for the similar thing in Seamstress, we
decided to follow suit.


=item * C<< MyApp::View::Seamstress->config->{skeleton} >>

By default this is not set and the HTML output is simply the result of
taking  C<< $c->stash->{template} >>, calling C<new()> to create
an HTML tree and then passing this to C<process()> so that it can rework
the tree.

However, if C<< MyApp::View::Seamstress->config->{skeleton} >> is
set, then both its value and the values of
C<< MyApp::View::Seamstress->config->{meat_pack} >>
and C<< $stash->{template}->fixup() >>
come into effect
as described in L<HTML::Seamstress/"The_meat-skeleton_paradigm">.

Let's take that a little slower: C<< $stash->{template}->fixup() >>
means: given a Seamstress-style Perl class, whose name is
C<< $stash->{template} >>, call the method C<fixup()> in that
class so that it can do a final fixup of the entire HTML that is about
to be shipped back to the client.


=back



The output generated by the template 
(and possibly its interaction with a skeleton) 
is stored in
C<< $c->response->body >>.




=for comment

 new()

The constructor for the Seamstress view 


=cut

sub new {
    my $self = shift;
    my $c    = shift;

    $self = $self->NEXT::new(@_);

    use Data::Dumper;
    warn "self_config(NEW): " . Dumper($self->config) ;
    warn "c_config(NEW): " . Dumper($c->config) ;
    $self;
  }



=for comment

 process()

C<< eval-requires >> the module specified in C<< $c->stash->{template} >>. 
Gets the 
C<HTML::Tree> representation of the file via C<new> and then calls 
C<< $self->process($c, $c->stash) >> to rewrite the tree. 

NOTE WELL: most views store output in C<< $c->response->body >>. Seamstress
stores it in C<< $c->stash->{woven} >>.


=cut

sub page2tree {
  my ($self, $c, $page_class, $process_method) = @_;

  $c->log->debug(qq/Rendering template "$page_class"/) if $c->debug;

  $process_method ||= 'process';

  my $page_object;

  if (not ref $page_class) {

    eval "require $page_class";

    if ($@) {
      my $error = qq/Couldn't load $page_class -- "$@"/;
      $c->log->error($error);
      $c->error($error);
      return 0;
    }

    $page_object = $page_class->new; # e.g html::hello_world->new

  } else {

    $page_object = $page_class;

  }

  my $tree;  eval { $tree = $page_object->$process_method($c, $c->stash) } ;

  if ( my $error = $@ ) {

    chomp $error;
    $error = qq/process() failed in "$page_class". Error: "$error"/;
    $c->log->error($error);
    $c->error($error);
    return undef;

  } else {

    return $tree;

  }

}

sub process {
    my ( $self, $c ) = @_;

    my ($skeleton, $meat, $body) ;

    #warn "self_config(PROCESS): " . Dumper($self->config) ;
    #warn "c_config(PROCESS): " . Dumper($c->config) ;


    # 
    # render $c->stash->{template}
    #

    my $template = $c->stash->{template};

    unless ($template) {
        $c->log->debug('No template specified for rendering') if $c->debug;
        return 0;
    }

    unless ( $c->response->content_type ) {
      $c->response->content_type('text/html; charset=utf-8');
    }


    if (ref($template) eq 'ARRAY') {

      map {
	$meat->{$_} = $self->page2tree($c, $_);
      } @$template;

    } else {

      $meat = $body = $self->page2tree($c, $template);

    }

    # 
    # render and pack MyApp::View::Seamstress->config->{skeleton}
    # if defined
    #

    if ($skeleton = $self->config->{skeleton}) {
      $skeleton = $self->page2tree($c, $skeleton);
      warn "SAH: ", $skeleton->as_HTML;
      $self->config->{meat_pack}->(
	$self, $c, $c->stash, $meat, $skeleton
       );

      # $body = $self->page2tree($c, $skeleton, 'fixup');
      # this should be additional controller actions for the request

      $body = $skeleton ;
    }

    # 
    # take the the body 
    #


    $c->response->body( $body->as_HTML(undef, ' ') );

    return 1;
}


=head1 Tips to View Writers

=head2 get config information from MyApp and MyApp::View::Seamstress

assuming C<Catalyst::View::Seamstress::new()> starts off
like this:

 sub new {
    my $self = shift;
    my $c    = shift;

C<< $self->config >> contains things set in C<MyApp::View::Seamstress>.
C<< $c->config >>    contains things set in C<MyApp>

assuming C<Catalyst::View::Seamstress::process()> starts off
similarly:

 sub process {
    my ( $self, $c ) = @_;

C<< $self->config >> contains things set in C<MyApp::View::Seamstress>.
C<< $c->config >>    contains things set in C<MyApp>.

There is no automatic merging of the two sources of configuration: you 
have to do that yourself if you want to do it.


=head2 


=head1 SEE ALSO

L<Catalyst>,
L<Catalyst::View>,
L<Catalyst::Helper::View::Seamstress>,
L<HTML::Seamstress>

=head2 A working sample app

The best way to see a fully working Seamstress-style Perl class is to
pull down the working sample app from sourceforge.

A working sample app, which does both simple and
meat-skeleton rendering is available from
Sourceforge CVS:

 cvs -d:pserver:anonymous@cvs.sourceforge.net:/cvsroot/seamstress login
 cvs -d:pserver:anonymous@cvs.sourceforge.net:/cvsroot/seamstress co -P catalyst-simpleapp

=head1 SUPPORT

Email the author or ping him on C<#catalyst> on C<irc.perl.org>

=head1 AUTHORS

Terrence Brannon <metaperl@gmail.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it 
under the same terms as Perl itself.

=cut

1;
