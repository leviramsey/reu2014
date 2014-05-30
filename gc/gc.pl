#!/usr/bin/perl
# Proposed GC algorithm

use strict;
use feature ':5.14';

use constant MEMORY_SIZE => 16;
use constant GC_FRACTION => 8;
use constant GC_AT => MEMORY_SIZE/GC_FRACTION;
use constant UNALLOCATED => '-1 unallocated';

# Memory... each cell consists of an integer corresponding to an object ID,
#  or "-1: unallocated" if unallocated
{
	my @memory;
	$#memory=MEMORY_SIZE-1;
	
	for (my $i=0; $i<MEMORY_SIZE; $i++) {
		$memory[$i]=UNALLOCATED;
	}

	sub mem_read { (my $off) = @_;
		if (($off < MEMORY_SIZE) && ($off >= 0)) {
			return $memory[$off];
		}
		return undef;
	}

	sub mem_write { (my $off, my $obj) = @_;
		if (($off < MEMORY_SIZE) && ($off >= 0)) {
			$memory[$off]=$obj;
			return $memory[$off];
		}
		return undef;
	}

	sub dump_memory {
		my $current_obj=undef;
		while ((my $cell_id, my $contents) = each @memory) {
			if ($contents == UNALLOCATED) {
				$current_obj=undef;
				say "$cell_id: unallocated";
			} else {
				next if (($current_obj==$contents) && (defined $current_obj));
				$current_obj=$contents;
				(my $id, my $size, my $refcount, my @refs) = dump_object($current_obj);
				say "$cell_id: Object $id: size $size, refcount $refcount" . ((scalar @refs) ? (", references " . join(", ", @refs)) : "");
			}
		}
	}
}

# Allocation state (separate from the memory)
{
	my $size_used=0;
	my @objects;
	my $gc_scan=0;

	# An object is a list:
	#  [ start_offset, size, refcount, refers_to ]
	sub memstats { return (MEMORY_SIZE, $size_used, MEMORY_SIZE-$size_used); }
	
	sub allocate_object { (my $size, my @referred_to) = @_;
		if (scalar grep {
			!((defined $objects[$_]) &&
			  ('ARRAY' eq ref $objects[$_]) &&
			  ($objects[$_]->[2] >= 0)); } @referred_to) {
			# Unrecoverable error
			die "Object refers to a nonexistent or invalid object";
		}

		my $available=MEMORY_SIZE-$size_used;
		if ($size > $available) {
			collect_garbage(num_to_collect());
			my $tmp=MEMORY_SIZE-$size_used;
			if ($tmp == $available) {
				# Nothing collected...
				return undef;
			}
			# An object could have been GC'd so tail-recur
			goto &allocate_object;
		}

		# First-fit
		my $obj=[ -1, $size, 1, \@referred_to ];
		{
			my $in_run=0;
			my $run_size;
			for (my $i=0; $i<MEMORY_SIZE; $i++) {
				if (mem_read($i) == UNALLOCATED) {
					unless ($in_run) {
						$run_size=0;
						$in_run=1;
					}
					$run_size++;
					if ($run_size == $size) {
						$obj->[0]=$i+1-$size;
						last;
					}
				} else {
					$in_run=0;
				}
			}
			say $run_size;
		}

		unless ($obj->[0] >= 0) {
			# too fragmented
			my $tmp=$size_used;
			collect_garbage(num_to_collect());
			if ($tmp == $size_used) {
				return undef;
			}
			# [tail-]recur
			goto &allocate_object;
		}

		$size_used+=$size;

		my $objid;
		for (my $i=0; 1; $i++) {
			unless (defined $objects[$i]) {
				$objects[$i]=$obj;
				$objid=$i;
				last;
			}
		}

		{
			my $start=$obj->[0];
			my $finish=$start+$size;
			for (my $i=$start; $i<$finish; $i++) {
				mem_write($i, $objid);
			}
		}

		# Update refcounts
		for (@referred_to) {
			$objects[$_]->[2]++;
		}

		return $objid;
	}

	sub oos_object { (my $id) = @_;
		unless ((defined $objects[$id]) &&
			    ('ARRAY' eq ref $objects[$id]) &&
				($objects[$id]->[2] > 0)) {
			die "Invalid object ID specified";
		}

		my $obj=$objects[$id];
		$obj->[2]=$obj->[2] - 1;
	}

	sub free_object { (my $id) = @_;
		unless ((defined $objects[$id]) &&
		        ('ARRAY' eq ref $objects[$id]) &&
				($objects[$id]->[2] == 0)) {
			die "Invalid object specified";
		}

		my $obj=$objects[$id];
		my @orphans=();

		for (@{$obj->[3]}) {
			my $ptr=$objects[$_];
			die "Invalid refcount" unless ($ptr->[2]);
			$ptr->[2]=$ptr->[2]-1;
			unless ($ptr->[2]) {
				push @orphans, $_;
			}
		}

		{
			my $start=$obj->[0];
			my $finish=$start+$obj->[1];
			for (my $i=$start; $i<$finish; $i++) {
				mem_write($i, UNALLOCATED);
			}
		}

		$objects[$id]=undef;
		$size_used-=$obj->[1];
		return @orphans;
	}

	sub num_to_collect {
		my $n=$size_used/GC_AT;
		my $ret=int(4 ** $n);
		return ($ret<MEMORY_SIZE) ? $ret : MEMORY_SIZE;
	}

	sub collect_garbage { (my $n) = @_;
		my @to_collect=();
		while ($n) {
			if (scalar @to_collect) {
				my $target=pop @to_collect;
				next unless (defined $objects[$target]);
				my @to_add=free_object($target);
				push @to_collect, @to_add;
				$n--;
			} else {
				my $objcount=scalar @objects;
				die "Can't GC" unless ($objcount);
				my $start_point=$gc_scan-1;
				$start_point=(($start_point >= $objcount) || ($start_point < 0)) ? ($objcount-1) : $start_point;

				while ($start_point != $gc_scan) {
					my $obj=$objects[$gc_scan];
					if ((defined $obj) &&
						(!($obj->[2]))) {
						say "Added $gc_scan to the to-collect list";
						push @to_collect, $gc_scan;
					}
					$gc_scan++;
					$gc_scan=($gc_scan >= $objcount) ? 0 : $gc_scan;
					last if (scalar @to_collect);
				}

				last unless (scalar @to_collect);
			}
		}
	}

	sub dump_object { (my $id) = @_;
		unless ((defined $objects[$id]) &&
		        ('ARRAY' eq ref $objects[$id])) {
			die "Invalid object $id specified";
		}

		my $obj=$objects[$id];
		my @ret=@{$obj};
		$ret[0]=$id;
		my @refs_from=@{$ret[3]};
		pop @ret;
		push @ret, @refs_from;
		return @ret;
	}
}

my %cmds=(
	a => sub { (my $size, my @refs) = @_;
		die "Must specify size" unless defined $size;

		my $id=allocate_object($size, @refs);
		if (defined $id) {
			say "Allocated object $id";
		} else {
			say "Not enough free memory";
		}
		printf("Memory stats: %d total, %d used, %d free\n", memstats);
	},
	d => \&dump_memory,
	o => sub {
		oos_object(@_);
		printf("Memory stats: %d total, %d used, %d free\n", memstats);
	}
);

while (<STDIN>) {
	(my $cmd, my @args) = split(/\s+/, $_);
	if (defined $cmds{$cmd}) {
		eval { $cmds{$cmd}->(@args) };
		if ($@) { print $@; }
	} else {
		say "Unknown command: $cmd";
	}
}
