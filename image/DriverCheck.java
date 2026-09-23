public class DriverCheck {
    public static void main(String[] args) throws Exception {
        Class<?> driver = Class.forName("org.postgresql.Driver");
        Object instance = driver.newInstance();
        Class<?> datasource = Class.forName("org.postgresql.ds.PGConnectionPoolDataSource");
        datasource.newInstance();
        System.out.println("DRIVER_LOAD_OK " + instance.getClass().getProtectionDomain().getCodeSource().getLocation());
        System.out.println("Java: " + System.getProperty("java.version"));
    }
}
