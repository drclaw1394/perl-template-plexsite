@{[
	init {
		output location=>"test_location", title=>"template1";
		inherit "templates/parent.plex";
		use Data::Dumper;
		
		$menu={
			order=>1,
			path=>"products/camera",
			label=>"Gen 2 Wireline Camera",
			icon=>"hello"
		};

		$res_=$self->add_resource("templates/res.txt");
		$local_=$self->add_plt_resource("local_to_plt.txt");
	}
]}

##START OF CHILD
@{[say STDERR "IN CHILD"]}
@{[fill_slot header=>"HEADER GOES HERE"]}
CONTENT FROM CHILD
This is a test1 html file
Referencing poducts/test2
<a href="$res->{$res_}">Link to res.txt</a>
$res->{$local_}
@{[locale->render]};
##END OF CHILD CONTENT
#

