const PhysicsEntity = struct {
    const Mobility = enum {
        rigid,
        static,
        part,
    };

    mobility: Mobility = .rigid, 
};
