//
// Common enums and errors
//
// This is the base dependency
//

//
// Common Error set
//
pub const ZrogueError = error{
    NotInitialized,
    ImplementationError, // Curses is annoying at least for now
};

//
// Results of the Thing.doAction() method, which drives what the game loop
// does next: keep going, plant a tombstone, declare victory, etc.
//
pub const ActionEvent = enum {
    NoEvent,
    QuittingGame,
};

// EOF
