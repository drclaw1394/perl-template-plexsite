package Template::Plexsite;

use v5.36;

use feature qw<say try>;

use Log::ger;
use Log::OK;

use feature qw<refaliasing say current_sub>;
no warnings "experimental";

#use Template::Plex::Internal;
use parent "Template::Plex";

our $VERSION="v0.1.0";
use File::Basename qw<dirname basename>;
use File::Spec::Functions qw<catfile catdir>;
use File::Path qw<mkpath>;
use Data::Dumper;

use constant KEY_OFFSET=>Template::Plex::KEY_COUNT+Template::Plex::KEY_OFFSET;
use enum ("dependencies_=".KEY_OFFSET,qw<locale_sub_template_ input_path_ output_path_ lander_>);
use constant KEY_COUNT=> output_path_- dependencies_+1;

sub new {
	my $package=shift;
	$package->SUPER::new(@_);
}


sub inherit {
	my $self=shift;
	unless($_[0]){
		Log::OK::INFO and log_info "undefined parent template. Disabling inheritance";
		return;
	}
	#TODO: Check that output has been called
	my $table=$self->args->{table}->table;
	my $entry=$table->{$self->args->{plt}};
	unless($entry->{output}){
		Log::OK::ERROR and log_error "inhert called before output in ". $self->args->{plt} ;
	}

	$self->SUPER::inherit(@_);
}

# Locates the first index.*.plex file in a plt directory and loads it
# as the body of the plt template.
sub load {
	my ($self, $path, $args, %options)=@_;
	Log::OK::TRACE and log_trace __PACKAGE__.": load called for $path";
	my $meta={};
	$meta=$self->meta if ref $self;

	#Force a template root for calls to super load
	my $root=$options{root}//=$meta->{root};

	#Path can be to a plt dir. If so find the index file and  load it
	my $tpath;

	if($path =~ /\.plt$/ and  -d "$root/$path"){
    # Match the first index file. Prefer file will plex/plx as the second last extension
		#First index.*.plex file
		Log::OK::DEBUG and log_debug __PACKAGE__." testing for index at $root/$path";
		($tpath)= < $root/$path/index.plex.*  $root/$path/index.plx.* $root/$path/index.*.plx $root/$path/index.*.plex >;
    Log::OK::DEBUG and log_debug "Found first path: $tpath";
		$tpath =~ s|^$root/||;
	}

	if($tpath){
		Log::OK::INFO and log_info __PACKAGE__.": index found: $tpath";
	}

	
	$tpath//=$path;

	#This is neede to make static class method work to load
	my %l_options=$meta->%*;
	$l_options{_input_path}=$path;
	$l_options{root}=$root;
	$l_options{base}=$options{base}//"Template::Plexsite";
	$l_options{use}=["Template::Plexsite::Common",
	];
	#wrappers subs to inject
	$l_options{inject}=[
		'sub output{ 
			$self->output(@_);
		}'
		,
		'sub locale {
			$self->locale(@_);
		}'
		,
		'sub res {
			$self->add_resource(@_);
		}'
		,
		'sub plt_res {
			$self->add_plt_resource(@_);
		}',
		'sub lander {
			$self->lander(@_);
		}'

	];

	my $template=$self->SUPER::load($tpath, $args, %l_options);
	$template;
}
sub pre_init {

	$_[0][input_path_]=$_[0]->meta->{_input_path};

}

sub post_init {
	my ($self)=@_;
	#Test if we have a local and load it 
	Log::OK::DEBUG and log_debug __PACKAGE__." post_init: ". $self->meta->{_input_path};
		my $root=$self->meta->{root};
		my $locale=$self->args->{locale};
		for ( $self->meta->{_input_path}) {
			#say "INPUT PATH $root/$_/$locale";
			if(/\.plt$/ and -d "$root/$_/$locale" ){
			Log::OK::DEBUG and log_debug __PACKAGE__." post_init looking for locale ".$self->args->{locale};
				$self->[locale_sub_template_]//=$self->locale;
			}
		}
}

sub no_locale_out{
  my $self=shift;
  $self->args->{no_locale_out}=1;
}

#Adds a resource. Input is relatative to root
#Output dir tree mirrors the in put tree
sub add_resource {
	my ($self, $input, @options)=@_;
	#use the URLTable object in args 	
	my $table=$self->args->{table};
	my $return=$table->add_resource($input, @options);
	
	#return the output relative path directly
	my $path=$table->map_input_to_output($input, $self->args->{plt});
	return $path;

		
}


#resolves an input file relative to the nearest plt dir.
#Sets up the output so it is also relative to the output dir
sub add_plt_resource {
	my ($self, $input, %options)=@_;
	#input is relative to the closes plt dir
	my $plt_dir=$self->[input_path_];
	while($plt_dir ne "." and basename($plt_dir)!~/plt$/){
		$plt_dir=dirname $plt_dir;
	}
	$options{output}=catfile dirname($self->output_path), $input;
	my $plt_input= catfile($plt_dir,$input);
	$self->add_resource(
		$plt_input,
		%options
	);
	
}



# Construct the output path base on:
# locale if defined
# output location (dir)
# output name if defined or basename of input template (minus the plex)
sub output_path {
	my $self=shift;
	\my %config = $self->args;
	return unless $config{output};	 #no output path when no output setup

	my $name=$config{output}{name};
	unless($name){
		#No explict output name so use the basename of input
		#without any plex suffix
		$name =basename $self->meta->{file};
		$name=~s/\.plex$|\.plx$//;  #Ending in plex/plx extension
		$name=~s/(?:\.plex|\.plx)(?=\.)//;  #Not ending in plex/plx extension
	}

  my $no_locale=$config{output}{no_locale};
	my @comps=( 
    $no_locale?():($config{locale}//()),   #add locale only if we want it
    $config{output}{location}||(),                     #If no location ensure an empty list
                                                        #to force root
    $name);
	my $path=catfile @comps;
}


#When called updates the computed table entry output field
#CALLED FROM WITHING A TEMLPATE
sub output {
	my $self=shift;
	my %options=@_;
	my $output=$self->args->{output}||={};

	#say 'Calling output';
	for(keys %options){

    # Clean up the location so it doesn't start with a slash
    # otherwise it breaks the output_path function
    #
    if($_ eq "location"){
      $options{$_}=~s|^/||;   
    }
    
		$output->{$_}=$options{$_};
	}
	#update the table entry
	my $table=$self->args->{table}->table;
	#say "Entry ". Dumper 
	my $entry=$table->{$self->args->{plt}};
	$entry->{output}=$self->output_path;
}


sub lander {
	my $self=shift;
	#my %options=@_;
	my ($lander)=@_;
	$self->[lander_]=$lander;
	
}

#Only works for plt templates
# Like a load call, but uses the information about the locale to 
# load a sub template
sub locale {
	my ($self, $lang_code)=@_;
	return $self->[locale_sub_template_] if $self->[locale_sub_template_];

	Log::OK::TRACE and log_trace __PACKAGE__." locale";
	my $dir=$self->meta->{_input_path};
	my $basename=basename $self->meta->{file};
	unless($lang_code){
		$lang_code=$self->args->{locale};
	}
	my $lang_template;
	#say STDERR "Language code is $lang_code";
	if($lang_code){
		$lang_template=catfile $dir,$lang_code//(), $basename;
		try {
			$self->[locale_sub_template_]=$self->load($lang_template, $self->args, $self->meta->%*);
		}
		catch($e){
			Log::OK::WARN and log_warn __PACKAGE__." Could not render template $lang_template. Using empty tempalte instead";
			Log::OK::WARN and log_warn __PACKAGE__." $e";
			$self->[locale_sub_template_]=Template::Plex->load([""]);#, $self->args, $self->meta->%*);

		}
	}
	else{
		#Log::OK::WARN and log_warn __PACKAGE__." no file found for locale=>$lang_code";

		$lang_template=[""];	
		#Dummy template
		#Log::OK::WARN and log_warn __PACKAGE__." attempt to render non existent locale template. Using empty tempalte instead";
		$self->[locale_sub_template_]=Template::Plex->load([""]);#, $self->args, $self->meta->%*);
	}
}

sub build{
	my $self=shift;
	my $result=$self->SUPER::render(@_);
	my $file=catfile $self->args->{html_root}, $self->output_path;
	mkpath dirname $file;		#make dir for output

	my $fh;
	unless(open $fh, ">", $file){
		Log::OK::ERROR and log_error "Could not open output location file $file";
	}

	Log::OK::DEBUG and log_debug("writing to file $file");
	print $fh $result;
	close $fh;

	#copy any resources this template neeeds?
	

	# Setup lander
  #
	if($self->[lander_]){
		Log::OK::INFO and log_info("Lander for ".$self->output_path." => ".$self->[lander_]);
		my $html_root=$self->args->{html_root};

		my $link=catfile($html_root,$self->[lander_]);
		if( -l $link){
			Log::OK::INFO and log_info("removing existing link");
			unlink $link;
		}
		#say "Symlink result: ".
		symlink $self->output_path, $link;#$self->args->{input};
	}
}





1;

__END__

=head1 NAME

Template::Plexsite - Class for interlinked templating

=head1 DESCRIPTION

A subclass of L<Template::Plex> which facilitates rendering hierrarchial
templates which are interlinked with one another. It works together with
L<Tempalte::Plexsite::URLTable> to render template to the correct output
location and utilise resources



=head1 API

=head2 output

Computes and returns the path to the output location this tempalte will render to. When
called updates the C<output> attribute in the URLTable object

=head2 locale

Loads a sub template specified by the locale key and returns it. The templates
is searched for in a dir which matches the locale name. The template is not
rendered


=head2 add resource

Adds a resource to the associate URLTable. Returns the resource in OUTPUT namespace


=head2 add_plt_resource

