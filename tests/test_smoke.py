def test_import():
    import pl_runner  # noqa: F401


def test_has_main():
    import pl_runner
    assert hasattr(pl_runner, "main")


def test_has_build_extraction_sql():
    import pl_runner
    assert hasattr(pl_runner, "build_extraction_sql")

## EOF 2026-01-15