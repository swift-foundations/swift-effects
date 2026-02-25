import Testing
import Effects_Built_in

@Test
func exitEffectHasCorrectCode() {
    let effect = Effect.Exit(code: 42)
    #expect(effect.code == 42)
}

@Test
func exitEffectZeroCode() {
    let effect = Effect.Exit(code: 0)
    #expect(effect.code == 0)
}
