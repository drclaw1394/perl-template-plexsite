package Template::Plexsite::URLTable;
use v5.36;
use feature qw<say try refaliasing>;
no warnings "experimental";

use Scalar::Util qw<weaken>;


use File::Basename qw<dirname>;
use Log::ger;
use Log::OK;

use Template::Plex;
use Template::Plexsite;

use File::Basename qw<dirname basename>;
use File::Spec::Functions qw<abs2rel rel2abs>;
use File::Path qw<mkpath>;
use File::Copy;

use constant::more ("root_=0", qw<html_root_ table_ locale_ dir_table_ nav_ templates_ ordered_>);

sub new {
	my $package=shift;
	my $self=[];
	my %options=@_;
	$self->[root_]=rel2abs($options{src});
	$self->[html_root_]=$options{html_root};
	$self->[table_]={};
	$self->[locale_]=$options{locale};
	$self->[nav_]={ 
		_data=>{
			label=>"/",
			href=>undef,
		}
	};
  $self->[ordered_]=[];

	bless $self, $package;
}


#resources are always refered in unnormalized input form
sub resource_info {
  my ($self, $input)=@_;
  $input=$self->normalize_input_path($input);
  $self->[table_]->{$input}
}


# Normalise input path as a relative path from src
sub normalize_input_path {
  my($self, $input)=@_;

	my $root=$self->[root_];
	my $path;
  if($input=~m|^/|){
    $input=abs2rel $input, $root;
    say STDERR "Relateive path from abs input PLEXSITE";
    say STDERR $input;
  }

  #$path=$root."/".$input;
  $input;
}


#Adds a resource with input relative to project root (src dir). 
#Absolute paths are converted into relative paths from project root.
#Options gives output and mode
#if input is a dir all items are added
sub add_resource {
  state $seq=0;
	my ($self, $input, %options)=@_;
	
	my $root=$self->[root_];
	\my %table=$self->[table_];

	my $return;


  ##########################################################
  #       my $path;                                        #
  # if($input=~m|^/|){                                     #
  #   $input=abs2rel $input, $root;                        #
  #   say STDERR "Relateive path from abs input PLEXSITE"; #
  #   say STDERR $input;                                   #
  # }                                                      #
  #
  #                                                        #
  # $path=$root."/".$input;                                #
  ##########################################################

  say STDERR "INPUT BEFORE NORMAL $input";
	$input=$self->normalize_input_path($input);
  say STDERR "INPUT AFTER NORMAL $input";
  my $path=$root."/".$input;                                #
  say STDERR "PATH AFTER  $path";
	#Show warning if resource is already included
  #
	if($table{$input}){
		Log::OK::WARN and log_warn "Resource: input $input already exists in table. Skipping";
    say STDERR $table{$input}{output};
		$return=$input;#$input;
		goto OUTPUT;
		#return $input;
	}

	#TODO: add filter to options for restricting file types
	


	#test if input actually exists
	unless( -e $path){
		Log::OK::WARN and log_warn __PACKAGE__." Resource: input $path does not exist.";
		return undef;
	}

	#Test if input is in fact a plain dir or a plt template
  #
  say STDERR "PATH IS $path";
	if(-d $path and $path =~ /plt$/){
		$return=$self->_add_template($input, %options);
		goto OUTPUT;

	}
  #elsif(-d $path){
  else{
		my @stack;
		my @inputs;
		#recursivy add resources
		#
		push @stack, $input;	
	
		#TODO: need to check that the file does not represent a html template
		while(@stack){
			my $item=pop @stack;
			#Log::OK::DEBUG	 and log_debug "Plexsite: TESTING item  $item";
			if( -d $item){
				#TODO: filter with filter in options
				push @stack, <"$item/*">;
			}
			else {
				push @inputs, $item;
			}
		}
		
		for(@inputs){

      
			#strip root from working dir relative paths from globbing
      #s/^$root\///;
      say STDERR "INPUT is: $_";
      say STDERR "ROOT is: $root";
      #$_=abs2rel $_, $root;
      say STDERR "NEW INPUT is: $_";
			my %opts=%options;
      $opts{static}{config}{output}{order}=$seq++;

      # Use forced output path if specified
      unless($options{output}){
			  $opts{output}=$_;
      }

      $opts{root}=$root;

      #TODO: based on processing confiration, match inputs to processing database and add any filters the table entry
      # $options{filter}//=DB->match ($_);
      # If no filter specified filter is copy by default
      # $options{filter}//={filter=>sub { copy }, inline=> 0}

			$table{$_}=\%opts;
		}
		$return=\@inputs;
		goto OUTPUT;

	}
    #########################################################################################
    #     else {                                                                            #
    #             #Assume a file                                                            #
    #             #add to url table                                                         #
    #             unless($options{output}){                                                 #
    #                     $options{output}=$input; #$t_out->{location}."/".$input;          #
    #             }                                                                         #
    # $options{root}=$root;                                                                 #
    #                                                                                       #
    #             my $in=$input;                                                            #
    #             $table{$in}=\%options;                                                    #
    #             Log::OK::INFO and log_info "Resource: Adding $in => $table{$in}{output}"; #
    #             $return=$in;#$options{output}//$in;                                       #
    #             goto OUTPUT;                                                              #
    #     }                                                                                 #
    #########################################################################################

	OUTPUT:
     
  ##############################################
  # use Data::Dumper;                          #
  #   say STDERR "RETURN IS: ".Dumper $return; #
  #   say STDERR "";                           #
  ##############################################
		if(ref($return) eq "ARRAY"){
      ##########################
      # if($return->@*==1){    #
      #   return $return->[0]; #
      # }                      #
      ##########################
			return $return->@*;
		}
		return $return 
		#return 1;
}


#setup config/vars for template
#setup table entry
#
sub _add_template {
	my ($self, $input, %options)=@_;

	Log::OK::INFO and log_info("Resource: Adding template $input");
	Log::OK::INFO and log_info("Resource: locale set to: $self->[locale_]");

	my $root=$self->[root_];

	my %opts;
	$opts{base}="Template::Plexsite";
	$opts{use}=["Template::Plexsite"];
	$opts{root}=$self->[root_];

	my %entry=(
		template=> {
			config=>{         # config is the hash used for lexical binding
        target=>$options{target},  # relative path to document. overrides plt for nav
				plexsite=>{},
				menu=>undef,		#Templates spec on menu	(stage 1)
				nav=>$self->[nav_],		#Acculated menu tree	(stage 2)
				output=>undef,		#Templates spec on output (state 1)
				locale=>$self->[locale_],	#Input local		(stage 1)
				#url_table=>{},		#DIR relative url lookup table (stage 2)
				res=>{},		#Alias for above
				table=>$self,		#Input URLTable object

				parent=>undef,		
				slots=>{},
				plt=>$input,		#Path to the input plt
				html_root=>$self->[html_root_]
			},
			template=>undef
		},

		output=>"",		#main 
		input=>$input,
    root=>$root,
	);

	weaken $entry{template}{config}{table}; 

	my ($index_file)= <"$root/$input/index.*" >;
	

	#strip $root from glob result for inputs
  #my $src=$index_file=~s|^$root/||r;
  my $src=abs2rel($index_file, $root);


	#Alias %config
	\my %config=$entry{template}{config};

	$self->[table_]{$input}=\%entry;	#Add before load

	#Inputs are dirs with plt extensions. A index.html page exists inside
	my $template=Template::Plexsite->load($input, \%config, %opts);

		$entry{template}{template}=$template;
		return $input;
	#If Output variable is set, we can add it to the list
        #################################################
        # if(defined $config{output}{location}){        #
        #         $entry{template}{template}=$template; #
        #         return $input;                        #
        # }                                             #
        # else {                                        #
        #         #say "LOCATION NOT SET for ",$src;    #
        # }                                             #
        #################################################

	return undef;
}

#Do a lookup of an input resource to find the resulting output url
sub lookup {
        my ($self,$input)=@_;
        $self->[table_]{$input};
}


##############################################################################
# #src and dest are input paths                                              #
# sub path_from_to {                                                         #
#         my ($self, $src, $dest)=@_;                                        #
#         #Input is relative to root                                         #
#         my $src_entry=$self->[table_]{$src};                               #
#         my $dest_entry=$self->[table_]{$dest};                             #
#                                                                            #
#         if($src_entry and $dest_entry){                                    #
#                 #build output path based on options in entry               #
#                 my $src_output=$src_entry->{output};                       #
#                 my $dir=dirname $src_output;                               #
#                                                                            #
#                 my $dest_output=$dest_entry->{output};                     #
#                 my $rel=abs2rel($dest_output, $dir);                       #
#                 return $rel;                                               #
#         }                                                                  #
#         undef;                                                             #
# }                                                                          #
#                                                                            #
# ## Create url tables which create outputs relative to output directories   #
# # The relative table is passed to the template at that dir level to allow  #
# # correct relative resolving of resources                                  #
# sub permute {                                                              #
#         my $self=shift;                                                    #
#         my $force=shift;                                                   #
#         return $self->[dir_table_] if $self->[dir_table_] and not $force;  #
#         Log::OK::INFO and log_info "Permuting outputs relative to inputs"; #
#         \my %table=$self->[table_];                                        #
#         my %dir_table;                                                     #
#                                                                            #
#         for my $input_path(keys %table){                                   #
#                 my $options=$table{$input_path};                           #
#                 my $output_path=$options->{output};                        #
#                                                                            #
#                 my $dir=dirname $output_path;                              #
#                 next if $dir_table{$dir};                                  #
#                 my $base=basename $output_path;                            #
#                 for my $input_path (keys %table){                          #
#                         my $options=$table{$input_path};                   #
#                         my $output_path=$options->{output};                #
#                         my $rel=abs2rel($output_path, $dir);               #
#                         $dir_table{$dir}{$input_path}=$rel;                #
#                 }                                                          #
#         }                                                                  #
#         $self->[dir_table_]=\%dir_table;                                   #
# }                                                                          #
##############################################################################

# Returns the relative path between two items in output name space, given the
# input name space target and reference
#
# If input is undefined, returns the relative "." path
#
sub map_input_to_output {
  use feature ":all";
	my ($self, $target, $reference)=@_;
  return "." unless $target;
  say STDERR "target: $target";
  say STDERR "reference: $reference";

  #say STDERR "target $target, referece $reference";

  # remove any fragments for lookup
  my ($input, $frag1)=split "#", $target;
  my ($input_reference, $frag2)=split "#", $reference;


	my $ref_entry=$self->table->{$reference};

	my $output_reference=$ref_entry->{output};
  say STDERR "Refernce  in output space", $output_reference;

	my $input_entry=$self->table->{$input};

  #TODO: check the processing options. 
  # If inline is specified, it will return content of file not a path immediately
  # If a filter is specified, inline data will be run through a filter an returned immediately
  #
  # If NOT inline (normal), the output path calculated alread will be returned. The contents will copied / filtered at build
	my $output=$input_entry->{output};
  say STDERR "res in output space", $output;
	#make relative path from output  reference to output
  if(substr($output_reference , -1)  eq '/'){
    # Randome value appended to make dirname work as expected
    $output_reference.="a";
  }
	my $o=abs2rel($output, dirname $output_reference);	

  # force a slash if arguments contain a slash
  if(substr($output,-1) eq "/"){
    $o.="/";
  }

  say STDERR "relative", $o;
  $o=$o."#".$frag1 if $frag1;
  $o;

  


}


#Generate sitemap xml file
sub site_map {

}

#copy/move/link resources into output locations
sub build {
	#Use options to direct execution
	#if render field is a string, it can be
	#	none 	=> do nothing with input
	#	copy	=> copy input to output location if input older than output
	#	link	=> link input to output location
	#	filter  => contents of file filtered through sub routine
	
	#if render field is a sub, it is called with the entry for processing
	#ie this could be a template
	my ($self, $main)=@_;
	

  say STDERR "+++++BeFORE RENDER TEMPLATES";
	my @res=$self->_render_templates;
  say STDERR "+++++AFTER RENDER TEMPLATES";
  
	$self->_static_files;
  say STDERR "+++++AFTER STATIC FILES";
	$self->_site_map;
  @res;
}

sub _site_map {
	my ($self)=@_;

}
sub _static_files {
	my ($self)=@_;
  #my $root=$self->[root_];
	my $html_root=$self->[html_root_];

  my @ordered=sort {$self->[table_]{$a}{static}{config}{output}{order} <=> $self->[table_]{$b}{static}{config}{output}{order}} keys $self->[table_]->%*;


  my $jpack=Data::JPack->new(jpack_compression=>"DEFLATE", jpack_type=>"app", html_container=>$html_root);

	#Process only entries with no template
  #for my $input (keys $self->[table_]->%*){
  for my $input (@ordered){
    say STDERR "";
    say STDERR "=--- Processing $input";
    say STDERR "";
		my $entry=$self->[table_]{$input};
		next if $entry->{template};
		Log::OK::TRACE and log_trace __PACKAGE__." static files: processing $input";


    my $root=$entry->{root};
    $input=$root."/".$input;
		my $output=$html_root."/".$entry->{output};

		mkpath dirname $output;

		my @stat_in=stat $input;
		my @stat_out=stat $output;
		unless(@stat_in){
			Log::OK::WARN and log_warn "Could not locate input: $input";
			next;
		}
      my $filter=$entry->{static}{config}{output}{filter};
      #use Data::Dumper;
      #say STDERR Dumper $entry->{static}{config}{output}{filter};

      #say STDERR Dumper @stat_out;
		if($filter or !$stat_out[9] or $stat_out[9] < $stat_in[9]){

      # Do filter here
      if($filter->{"name"} eq "jpack"){
			Log::OK::INFO and log_info("JPACK filter $input");
        #$self->_jpack($filter); 
        # Set prefix
        my $prefix=$filter->{prefix};
        unless($prefix){
          if($input=~/\.css$/){
            $prefix="app/jpack/css";
          }
          elsif($input=~/\.js$/){
            $prefix="app/jpack/main";
          }
        }
        $jpack->set_prefix($prefix);
        my $output=$jpack->next_file_name($input);
        say STDERR "NEXT FILT NAME $output";
        $jpack->encode_file($input, $output);

           

      }
      else {
			Log::OK::INFO and log_info("COPY $input=> $output");
			  copy $input, $output;
      }



		}
		else {
			Log::OK::DEBUG and log_debug("Upto date: $input=> $output");
		}


	}
	
}

sub _jpack {
  my ($self, $filter)=@_;

  
}


#Work all template resources
# Does a lookup on the permuted output dirs
sub _render_templates {
	my ($self)=@_;
  my @inline_results;

	Log::OK::TRACE and log_trace "URLTable: _render_templates";

  # Sort the templates by relative rendering order of output
  # This gives accumulation type templates to work

  my @templates=$self->ordered_entries;

	#render all resources
  #for my $input (keys $self->[table_]->%*){
    #my $entry= $self->[table_]{$input};
  for my $entry(@templates){
		next unless $entry->{template};
		try {
			my $template=$entry->{template}{template};
      if(defined $template){
        #Log::OK::INFO and log_info "Rendering template $input  => ".$template->output_path;
        Log::OK::INFO and log_info "Rendering template   => ".$template->output_path;

        push @inline_results, $template->build;
      }
      else {
        Log::OK::INFO and log_info "No output location for template $entry->{template}{config}{plt}. Ignoring";
        
      }
		}
		catch($e){
      #Log::OK::ERROR and log_error __PACKAGE__." Could not render $input: $e";	
			Log::OK::ERROR and log_error $e;
		};
	}
  @inline_results;
}

# Sort template entries by the specified render order
sub ordered_entries {
  my ($self)=@_;

  # First it gives entries an order if not already set

    #find the current max order
    my $max; 
    use List::Util qw<any pairs>;
    my @pairs=
      grep {defined $_->[1]{template}}
      pairs $self->[table_]->%*;


    for my $p (@pairs){
      for($p->[1]{template}{config}{output}{order}){
        
        unless(defined($max)){
          $max=$_;
          next;
        }
        $max=$_ if defined($_) and $_>$max;
      }
    }
    $max//=0;



    #sort {$a->{template}{config}{output}{order} <=> $b->{template}{config}{output}{order}} values $self->[table_]->%*;
    map $_->[1],
    sort {$a->[1]{template}{config}{output}{order} <=> $b->[1]{template}{config}{output}{order}}
    map {$_->[1]{template}{config}{output}{order}//= ++$max; $_; }
    @pairs;
}

sub clear {
	$_[0][table_]={};
}

sub table :lvalue{
	$_[0][table_];
}
1;
