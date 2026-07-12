namespace LingoRoad.Domain;

public static class CefrMap
{
    public static string FromTheta(double theta) => theta switch
    {
        < -1.5 => "A1", < -0.5 => "A2", < 0.5 => "B1",
        < 1.5 => "B2", < 2.25 => "C1", _ => "C2"
    };
}
