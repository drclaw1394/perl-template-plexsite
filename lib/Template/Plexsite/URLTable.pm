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
use File::Spec::Functions qw<abs2rel>;
use File::Path qw<mkpath>;
use File::Copy;
use Data::Dumper;

use enum ("root_=0", qw<html_root_ table_ locale_ dir_table_ nav_ templates_>);

sub new {
	my $package=shift;
	my $self=[];
	my %options=@_;
	$self->[root_]=$options{src};
	$self->[html_root_]=$options{html_root};
	$self->[table_]={};
	$self->[locale_]=$options{locale};
	$self->[nav_]={ 
		_data=>{
			label=>"/",
			href=>undef,
		}
	};

	bless $self, $package;
}


#Adds a resource with input relative to project root
#Options gives output and mode
#if input is a dir all items are added
sub add_resource {
	my ($self, $input, %options)=@_;
	
	my $root=$self->[root_];
	\my %table=$self->[table_];
	my $return;
	#Show warning if resource is already included
	if($table{$input}){
		#Log::OK::WARN and log_warn "Resource: input $input already exists in table. Skipping";
		$return=$input;
		goto OUTPUT;
		#return $input;
	}

	#TODO: add filter to options for restricting file types
	

	#Test if input is infact a dir
	my $path=$root."/".$input;
	#test if input actually exists
	unless( -e $path){
		Log::OK::WARN and log_warn __PACKAGE__." Resource: input $path does not exist.";
		return undef;
	}

	if(-d $path and $path =~ /plt$/){
		$return=$self->_add_template($input);
		goto OUTPUT;

	}
	elsif(-d $path){
		my @stack;
		my @inputs;
		#recursivy add resources
		#
		push @stack, $path;	
	
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
			s/^$root\///;
			my %opts=%options;
			$opts{output}=$_;

			$table{$_}=\%opts;
		}
		$return=\@inputs;
		goto OUTPUT;

	}
	else {
		#Assume a file
		#add to url table	
		unless($options{output}){
			$options{output}=$input; #$t_out->{location}."/".$input;
		}

		my $in=$input;
		$table{$in}=\%options;
		Log::OK::INFO and log_info "Resource: Adding $in => $table{$in}{output}";
		$return=$in;
		goto OUTPUT;
	}

	OUTPUT:
		if(ref($return) eq "ARRAY"){
			return $return->@*;
		}
		return $return 
		#return 1;
}


#setup config/vars for template
#setup table entry
#
sub _add_template {
	my ($self,$input)=@_;
	Log::OK::INFO and log_info("Resource: Adding template $input");
	Log::OK::INFO and log_info("Resource: locale set to: $self->[locale_]");
	my $root=$self->[root_];

	my %opts;
	$opts{base}="Template::Plexsite";
	$opts{use}=["Template::Plexsite"];
	$opts{root}=$self->[root_];

	my %entry=(
		template=> {
			config=>{
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
	);

	weaken $entry{template}{config}{table}; 

	my ($index_file)= <"$root/$input/index.*" >;
	

	#strip $root from glob result for inputs
	my $src=$index_file=~s|^$root/||r;

	#strip plex $input and extension if present
	#my $target=$src=~s/\.plex$|\.plx$//r;
	#$target=~s|$input/||;

	#Alias %config
	\my %config=$entry{template}{config};

	$self->[table_]{$input}=\%entry;	#Add before load
	#Inputs are dirs with plt extensions. A index.html page exists inside
	my $template=Template::Plexsite->load($input, \%config, %opts);
	#If Output variable is set, we can add it to the list
	if(defined $config{output}{location}){
		#Process menu entry if required
		#
		if($config{menu}){
			Log::OK::DEBUG and log_debug "Template sets a menu entry. Adding to navigation";

			#Split the menu item
			my @parts=split m|/|, $config{menu}{path};
			Log::OK::DEBUG and log_debug "Menu path will be: ". join ", ", @parts;

			my $parent=$config{nav};
			for(@parts){
				$parent = $parent->{$_}//={};
			}

			$parent->{_data}{href}//=$input;

			for( keys $config{menu}->%*){
				next if $_ eq "path";
				$parent->{_data}{$_}=$config{menu}{$_};
			}
		}
			
		#add entry to output file table
		#$entry{output}=$config{locale}."/".$config{output}{location}."/".$target;

		$entry{template}{template}=$template;
		#$entry{output}=$template->output_path;
		return $input;
	}
	else {
		#say "LOCATION NOT SET for ",$src;
	}

	return undef;
}

######################################################################
# #Do a lookup of an input resource to find the resulting output url #
# sub lookup {                                                       #
#         my ($self,$input, $base)=@_;                               #
#         $self->[table_]{$input};                                   #
# }                                                                  #
######################################################################


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

sub map_input_to_output {
	my ($self,$input, $input_reference)=@_;
  #say "want input: $input,  relative to: $input_reference";

	my $ref_entry=$self->table->{$input_reference};
  #say  Dumper $ref_entry;

	my $output_reference=$ref_entry->{output};

	my $input_entry=$self->table->{$input};
	my $output=$input_entry->{output};
	#say Dumper $self->table;
	#say Dumper $input_entry;
  #say "Output field of referenc in put is: $output_reference";
  #say Dumper $output_reference;

	#make relative path from output  reference to output
	abs2rel($output,dirname $output_reference);	

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
	my ($self)=@_;
	

	$self->_render_templates;
	$self->_static_files;
	$self->_site_map;
}

sub _site_map {
	my ($self)=@_;

}
sub _static_files {
	my ($self)=@_;
	my $root=$self->[root_];
	my $html_root=$self->[html_root_];

	#Process only entries with no template
	for my $input (keys $self->[table_]->%*){
		my $entry=$self->[table_]{$input};
		next if $entry->{template};
		Log::OK::TRACE and log_trace __PACKAGE__." static files: processing $input";


		$input=$root."/".$input;
		my $output=$html_root."/".$entry->{output};

		mkpath dirname $output;

		my @stat_in=stat $input;
		my @stat_out=stat $output;
		unless(@stat_in){
			Log::OK::WARN and log_warn "Could not locate input: $input";
			next;
		}

		if(!$stat_out[9] or $stat_out[9] < $stat_in[9]){
			Log::OK::INFO and log_info("COPY $input=> $output");
			copy $input, $output;
		}
		else {
			Log::OK::DEBUG and log_debug("Upto date: $input=> $output");
		}


	}
	
}

#Work all template resources
# Does a lookup on the permuted output dirs
sub _render_templates {
	my ($self)=@_;
	Log::OK::TRACE and log_trace "URLTable: _render_templates";
	#render all resources
	for my $input (keys $self->[table_]->%*){
		my $entry= $self->[table_]{$input};
		next unless $entry->{template};
		try {
			my $template=$entry->{template}{template};
			#my $dir_table=$self->permute->{dirname $template->output_path};
			Log::OK::INFO and log_info "Rendering template $input  => ".$template->output_path;
			#$self->[table_]{$input}{template}{config}{res}=$dir_table;
			#Log::OK::INFO and log_info Dumper $dir_table;

			$template->build;
		}
		catch($e){
			Log::OK::ERROR and log_error __PACKAGE__." Could not render $input: $e";	
			Log::OK::ERROR and log_error $e;
		};
	}

}

sub clear {
	$_[0][table_]={};
}

sub table{
	$_[0][table_];
}
1;
