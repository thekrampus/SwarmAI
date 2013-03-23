/**
 * Swarm AI by Rob Kelly
 *
 * based on Craig Reynolds's "Boids" flocking simulation - http://www.red3d.com/cwr/boids/
 * plus a few modifications of my own.
 * neat fact: Though the swarm behavior looks random, the simulation is actually entirely
 * deterministic except for randomized starting positions and user input.
 *
 * Controls: Left mouse to drag target, right mouse to spawn boids
 *           - to remove target, Backspace to remove boids, q to cycle quality
 */

ArrayList<Boid> boids;
PVector target;
float targetRotation;
//color[] palette = {#a3a948, #edb92e, #f85931, #ce1836, #009989, #2f8135};
//color[] palette = {#f8f087, #b7e3c0, #b8d0dd, #dbbae5, #f39dd4};
color[] palette = {#490a3d, #bd1550, #e97f02, #f8ca00, #8a9b0f, #00a0b0};
int quality = 3;

void setup() {
  size(800, 850);
  
  //populate list with initial boids
  boids = new ArrayList();
  for(int i = 0; i < 7; i++)
    boids.add(new Boid(random(width), random(height)));
  
  //target starts out in the center of the screen
  target = new PVector(width/2, height/2);
  targetRotation = 0;
  smooth(8);
}

void draw() {
  background(128);
  
  if(target != null) 
    drawTarget();
  
  for(Boid b : boids) {
    b.act();
    b.display();
  }
  
  fill(0);
  text(frameRate + " fps", 0, 10);
  text(boids.size() + " boids", 0, 20);
  text("smoothing " + quality, 0, 30);
}

void mouseDragged() {
  if(mouseButton == LEFT)  // dragging with the left mouse button moves the target
    target = new PVector(mouseX, mouseY);
  else if(mouseButton == RIGHT)  // " with the right mouse button spawns a whole buncha Boids
    boids.add(new Boid(mouseX, mouseY));
}

void keyPressed() {
  if(key == '-')  // remove target when minus key is pressed
    target = null;
  else if(key == 'q') // toggle draw quality with q key
    toggleQuality();
  else if(key == BACKSPACE && boids.size() >= 3) // remove a couple of boids when backspace key is pressed
    for(int i=0; i<3; i++) boids.remove(0);
}

/**
 * Cycle quality through values 0, 2, 4, 8
 * 8 being smoothest and 0 being no smoothing
 */
void toggleQuality() {
  quality = (quality + 1)%4;
  if(quality == 0)
    noSmooth();
  else
    smooth(int(pow(2, quality)));
}

/**
 * Draw target to screen
 */
void drawTarget() {
  pushMatrix();
  pushStyle();
  //strokeWeight(2);
  noFill();
  stroke(0, 255, 0);
  translate(target.x, target.y);
  rotate(targetRotation);
  
  arc(0, 0, 20, 20, 0, HALF_PI);
  arc(0, 0, 20, 20, PI, PI+HALF_PI);
  //line(-10, 0, 10, 0);
  //line(0, -10, 0, 10);
  
  popStyle();
  popMatrix();
  
  targetRotation = (targetRotation + 0.01) % PI;
}

class Boid {
  static final int LENGTH = 16,          // sprite length in pixels
                   SIGHT = 80,           // maximum distance between to swarm-mates
                   COMFORT_ZONE = 20;    // target minimum distance between swarm-mates
  static final float SPEED = 1.0/10.0,  // relative movement speed, higher is faster
                     FRICTION = 0.97,    // 0 = superglue, 1 = teflon
                     COOPERATION = 0.1; // how readily a swarm works together
  public PVector coord,                  // screen coordinate of this Boid
                 vel;                    // velocity vector
  public int colorIndex;
  
  Boid(float x, float y) {
    coord = new PVector(x, y);
    vel = new PVector(0, 0);
    colorIndex = int(random(palette.length));
  }
  
  /**
   * Play through one cycle of the Boid swarm AI routine
   */
  void act() {
    
    // Compile a list of Boids in the local swarm; update colors while we're at it
    ArrayList<Boid> swarm = new ArrayList();
    int[] colorCount = new int[palette.length];
    for(Boid b : boids){
      if(coord.dist(b.coord) <= SIGHT) {
        swarm.add(b);
        colorCount[b.colorIndex]++;
      }
    }
    for(int i=0; i<colorCount.length; i++)
      if(colorCount[i] > colorCount[colorIndex])
        colorIndex = i;
    
    // Build a velocity vector out of our rules
    vel.add(cohesion(swarm));
    vel.add(separation(swarm));
    vel.add(alignment(swarm));
    if(target != null)
      vel.add(seekTarget(target));
    
    // Euclidean integration, plus boundary check on each axis separately
    coord.x += vel.x;
    if(coord.x > width || coord.x < 0) {
      coord.x -= vel.x;
      vel.x *= -1;
    }
    coord.y += vel.y;
    if(coord.y > height || coord.y < 0) {
      coord.y -= vel.y;
      vel.y *= -1;
    }
    
    vel.mult(FRICTION);
  }
  
  /**
   * Rule 1 of the Boid swarm AI routine:
   * Boids try to fly towards the center of mass of their swarm.
   */
  PVector cohesion(ArrayList<Boid> swarm) {
    // determine center of mass
    PVector center = new PVector(0, 0);
    for(Boid b : swarm) {
      if(!b.equals(this))
        center.add(PVector.div(b.coord, swarm.size()-1));
    }
    
    if(swarm.size() == 1)
      return new PVector(0, 0);
    else
      return seekTarget(center);
  }
  
  /**
   * Rule 2 of the Boid swarm AI routine:
   * Boids try to avoid crowding the swarm
   */
  PVector separation(ArrayList<Boid> swarm) {
    PVector repulsion = new PVector(0, 0);
    for(Boid b : swarm) {
      PVector difference = PVector.sub(b.coord, this.coord);
      if(!b.equals(this) && difference.mag() < COMFORT_ZONE)
      repulsion.sub(PVector.div(difference, pow(difference.mag(), 2)/4));
        //repulsion.sub(PVector.div(difference.normalize(null), difference.mag()/4)); //This line crashes javascript!
    }
    
    return repulsion;
  }
   
  /**
   * Rule 3 of the Boid swarm AI routine:
   * Boids steer towards the average heading of the swarm
   */
  PVector alignment(ArrayList<Boid> swarm) {
    // same idea as cohesion, but for velocity.
    PVector avgVel = new PVector(0, 0);
    for(Boid b : swarm) {
      if(!b.equals(this))
        avgVel.add(PVector.div(b.vel, swarm.size()-1));
    }
    
    if(swarm.size() == 1)
      return new PVector(0, 0);
    else
      return PVector.mult(PVector.sub(avgVel, vel), COOPERATION);
  }
    
  /**
   * Steer Boids to a given coordinate
   */
  PVector seekTarget(PVector seek) {
    PVector diff = PVector.sub(seek, coord);
    diff.normalize();
    diff.mult(SPEED);
    return diff;
  }
    
  /**
   * Draws this Boid to the screen
   */
  void display() {
    pushMatrix(); 
    
    translate(coord.x, coord.y);
    //rotate(vel.heading()); //This line crashes javascript!
    rotate(atan2(vel.y, vel.x));
    fill(palette[colorIndex]);
    triangle(0, 0, -LENGTH, LENGTH/3, -LENGTH, -LENGTH/3);
    
    popMatrix();
  }
}

