BASEDIR = "#{File.dirname($0)}/../.."
$:.insert(0, "#{BASEDIR}/lib")

require 'minitest/autorun'
require 'findit'

P1_LAT_DEG = 30.286
P1_LNG_DEG = -97.739
P1_LAT_RAD = 0.52859 
P1_LNG_RAD = -1.7058

P2_LAT_DEG = 30.264
P2_LNG_DEG = -97.747

# 1 radian ~ 50 - 70 miles => 1 mile ~ 0.14 - 0.20 radians => 0.01 miles ~ 0.0014 - 0.0020 radians
DELTA_RADIANS = 0.0007 # to round accurately to nearest 1/100th mile
DELTA_DEGREES = DELTA_RADIANS*(360/Math::PI)
DELTA_MILES = 0.005

class TestCoordinate < MiniTest::Unit::TestCase

  def test_constructor_degrees
    p = Coordinate.new(P1_LAT_DEG, P1_LNG_DEG, :DEG)
    refute_nil p
    assert_in_delta P1_LAT_DEG, p.latitude_deg, DELTA_DEGREES
    assert_in_delta P1_LNG_DEG, p.longitude_deg, DELTA_DEGREES
    assert_in_delta P1_LAT_RAD, p.latitude_rad, DELTA_RADIANS
    assert_in_delta P1_LNG_RAD, p.longitude_rad, DELTA_RADIANS
  end
  
  def test_constructor_radians
    p = Coordinate.new(P1_LAT_RAD, P1_LNG_RAD, :RAD)
    refute_nil p
    assert_in_delta P1_LAT_RAD, p.latitude_rad, DELTA_RADIANS
    assert_in_delta P1_LNG_RAD, p.longitude_rad, DELTA_RADIANS
    assert_in_delta P1_LAT_DEG, p.latitude_deg, DELTA_DEGREES
    assert_in_delta P1_LNG_DEG, p.longitude_deg, DELTA_DEGREES
  end
  
  def test_distance_to_coord
    p1 = Coordinate.new(P1_LAT_DEG, P1_LNG_DEG, :DEG)
    p2 = Coordinate.new(P2_LAT_DEG, P2_LNG_DEG, :DEG)
    assert_in_delta 1.594, p1.distance(p2), DELTA_MILES
  end  
  
  def test_distance_to_location
    p1 = Coordinate.new(P1_LAT_DEG, P1_LNG_DEG, :DEG)
    assert_in_delta 1.594, p1.distance(P2_LAT_DEG, P2_LNG_DEG, :DEG), DELTA_MILES
  end  
  
end

class TestFindIt < MiniTest::Unit::TestCase
  
  def setup
    @f = FindIt.new(P1_LAT_DEG, P1_LNG_DEG)
  end
  
  def test_constructor
    refute_nil @f
    refute_nil @f.loc
    assert_in_delta P1_LAT_DEG, @f.loc.latitude_deg, DELTA_DEGREES
    assert_in_delta P1_LNG_DEG, @f.loc.longitude_deg, DELTA_DEGREES
    assert_equal "facilities.db", @f.database
    assert_equal "facilities", @f.table
    refute_nil @f.dbh
  end
  
  def test_constructor_options
    @f1 = FindIt.new(P1_LAT_RAD, P1_LNG_RAD, :type => :RAD, :database => "./test/data/empty.db", :table => "does_not_exist")
    refute_nil @f
    refute_nil @f.loc
    assert_in_delta P1_LAT_RAD, @f.loc.latitude_rad, DELTA_RADIANS
    assert_in_delta P1_LNG_RAD, @f.loc.longitude_rad, DELTA_RADIANS
  end
  
  def test_constructor_database_missing
    assert_raises(RuntimeError) {
      FindIt.new(P1_LAT_DEG, P1_LNG_DEG, :database => "does_not_exist.db")
    }
  end
  
  def test_closest
    a = @f.closest_facility("POST_OFFICE")
    refute_nil a
    assert_equal "POST_OFFICE", a["type"]
    assert_equal "West Mall University Of Texas Station", a["name"]
    assert_equal "2201 Guadalupe", a["address"]
    assert_equal "Austin", a["city"]
    assert_equal "TX", a["state"]
    assert_in_delta 30.2810, a["latitude"], DELTA_DEGREES
    assert_in_delta -97.7335, a["longitude"], DELTA_DEGREES
    assert_in_delta 0.52850, a["latitude_rad"], DELTA_RADIANS
    assert_in_delta -1.7058, a["longitude_rad"], DELTA_RADIANS
    assert_in_delta 0.410, a["distance"], DELTA_MILES
  end
  
  def test_nearby
    a = @f.nearby
    refute_nil a
    assert_equal 4, a.length
    assert_equal %w(FIRE_STATION LIBRARY MOON_TOWER POST_OFFICE), a.keys.sort
    assert_equal "506 W Martin Luther King Blvd", a["FIRE_STATION"]["address"]
    assert_equal "810 Guadalupe St", a["LIBRARY"]["address"]
    assert_equal "2110 Nueces Street", a["MOON_TOWER"]["address"]
    assert_equal "2201 Guadalupe", a["POST_OFFICE"]["address"]
  end
    
end

    
