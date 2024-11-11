use ExtUtils::MakeMaker;
WriteMakefile(
MIN_PERL_VERSION	=> v5.36,
    NAME              => 'Template::Plexsite',
    VERSION_FROM      => 'lib/Template/Plexsite.pm',
    PREREQ_PM         => {
	    "Template::Plex"=>0.7.0,
	    "Log::ger"=> 0,
      "Logger::Output::Screen"=>0

    },
    EXE_FILES =>[
		'script/plexsite'
	],
    ABSTRACT_FROM     => 'lib/Template/Plexsite.pm', # retrieve abstract from module
    AUTHOR            => 'Ruben Westerberg <drclaw@mac.com>',
    LICENSE           => 'mit',
);

