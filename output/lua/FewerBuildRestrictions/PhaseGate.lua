function CheckSpaceForPhaseGate(techId, origin, normal, commander)
    return GetHasRoomForCapsule(Vector(Player.kXZExtents+0.1, Player.kYExtents+0.1, Player.kXZExtents+0.1), origin + Vector(0, Player.kYExtents, 0), CollisionRep.Default, PhysicsMask.AllButPCsAndRagdolls)
end
