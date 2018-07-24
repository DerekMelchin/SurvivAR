class LocationComponent < GKComponent
  attr_accessor :node

  def init
    super
    target_geometry = SCNSphere.sphereWithRadius(0.1)
    target_material = SCNMaterial.material
    target_material.diffuse.contents = NSColor.colorWithRed(0, green: 0, blue: 0, alpha: 0)
    target_geometry.materials = [target_material]
    @node = SCNNode.nodeWithGeometry(target_geometry)
    self
  end
end